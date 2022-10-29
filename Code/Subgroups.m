/**********************************************************
This file supports computation of subgroups of abstract groups.

Which subgroups we compute and store is determined by the function
SetSubgroupParameters
**********************************************************/

VS_QUOTIENT_CUTOFF := 5; // if G has a subquotient vector space of dimension larger than this, we always compute up to automorphism;
NUM_SUBS_RATCHECK := 128; // if G has less than this many subgroups up to conjugacy, we definitely compute them up to conjugacy (and the orbits under Aut(G)
NUM_SUBS_RATIO := 2; // if G has between NUM_SUBS_RATCHECK and NUM_SUBS_CUTOFF_CONJ subgroups up to conjugacy, we record up to conjugacy (and the orbits under Aut(G))
NUM_SUBS_CUTOFF_CONJ := 1024; // if G has at least this many subgroups up to conjugacy, we definitely compute subgroups up to automorphism
NUM_SUBS_CUTOFF_AUT := 4096; // if G has at least this many subgroups up to automorphism, we only compute subgroups up to automorphism, and up to an index bound
NUM_SUBS_LIMIT_AUT := 1024; // if we compute up to an index bound, we set it so that less than this many subgroups up to automorphism are stored
LAT_CUTOFF := 4096; // if G has less than this many subgroups up to automorphism, we compute inclusion relations for the lattices of subgroups (both up-to-automorphism and, if present, up-to-conjugacy)

function AllSubgroupsOk(G)
    // A simple heuristic on whether Subgroups(G) might take a very long time
    E := ElementaryAbelianSeriesCanonical(G);
    for i in [1..#E-1] do
        if Factorization(Order(E[i]) div Order(E[i+1]))[1][2] gt VS_QUOTIENT_CUTOFF then
            return false;
        end if;
    end for;
    return true;
end function;

intrinsic outer_equivalence(G::LMFDBGrp) -> Any
{Whether subgroups are computed up to automorphism (vs only up to conjugacy)}
    if not Get(G, "HaveHolomorph") then
        return false;
    end if;
    byA := Get(G, "SubGrpLstAut");
    if #byA ge NUM_SUBS_CUTOFF_CONJ or byA`index_bound ne 0 or not AllSubgroupsOk(G`MagmaGrp) then
        // too many subgroups up to automorphism, so we don't need to compute the list up to conjugacy
        //printf "%o subgroups up to automorphism (min order %o, ok %o), so not computing up to conjugacy\n", #byA, byA[1]`order, AllSubgroupsOk(GG);
        return true;
    end if;
    byC := Get(G, "SubGrpLst");
    //print #byA, "subgroups up to automorphism,", #byC, "subgroups up to conjugacy";
    return (#byC ge NUM_SUBS_RATCHECK and #byC ge NUM_SUBS_RATIO * #byA);
end intrinsic;

intrinsic subgroup_index_bound(G::LMFDBGrp) -> RngIntElt
{}
    byA := Get(G, "SubGrpLstAut");
    if Get(G, "outer_equivalence") and byA`index_bound ne 0 then
        return byA`index_bound;
    end if;
    return 0;
end intrinsic;

intrinsic SetBigSubgroupParameters(G::LMFDBGrp)
{Set the parameters assuming that everything is hard (for example if G is very large)}
    G`outer_equivalence := false; // automorphism group is hard
    G`subgroup_index_bound := 3; // Maybe we can get a few
    G`all_subgroups_known := false; // trillions of subgroups
    G`normal_subgroups_known := true; // let us hope!
    G`maximal_subgroups_known := true; // let us hope!
    G`sylow_subgroups_known := true; // this is actually doable even for large groups
    G`subgroup_inclusions_known := false; // there are no inclusions if we're only going up to index 3
end intrinsic;

intrinsic SetSubgroupParameters(G::LMFDBGrp)
    {Set the parameters for which subgroups to compute (and do some initial computations)}
    GG := G`MagmaGrp;
    byA := Get(G, "SubGrpLstAut");
    if #byA ge NUM_SUBS_CUTOFF_CONJ or byA`index_bound ne 0 or not AllSubgroupsOk(GG) then
        // too many subgroups up to automorphism, so we don't need to compute the list up to conjugacy
        //printf "%o subgroups up to automorphism (min order %o, ok %o), so not computing up to conjugacy\n", #byA, byA[1]`order, AllSubgroupsOk(GG);
        G`outer_equivalence := true;
    else
        byC := Get(G, "SubGrpLst");
        //print #byA, "subgroups up to automorphism,", #byC, "subgroups up to conjugacy";
        G`outer_equivalence := (#byC ge NUM_SUBS_RATCHECK and #byC ge NUM_SUBS_RATIO * #byA);
    end if;
    if G`outer_equivalence and byA`index_bound ne 0 then
        G`subgroup_index_bound := byA`index_bound;
        G`all_subgroups_known := false;
    else
        G`subgroup_index_bound := 0;
        G`all_subgroups_known := true;
    end if;
    G`normal_subgroups_known := true;
    G`maximal_subgroups_known := true;
    G`sylow_subgroups_known := true;
    G`subgroup_inclusions_known := (#byA lt LAT_CUTOFF and byA`index_bound eq 0);
    // Now determine whether we compute characters
    F := Factorization(Get(G, "order"));
end intrinsic;

RF := recformat<subgroup, order, length>;
declare type SubgroupLatElt;
declare attributes SubgroupLatElt:
        Lat,
        subgroup,
        order,
        gens,
        sort_gens, // used for labeling: a canonical choice of generators of some subgroup in this class; independent of which subgroup was initially chosen
        sort_pick, // the subgroup generated by sort_gens.  This can be set without sort_gens if normal
        sort_conj, // an element conjugating subgroup to sort_pick
        aut_sort_gens, // used for labeling: a canonical choice of generators of some subgroup in this class; independent of which subgroup was initially chosen
        aut_sort_pick, // the subgroup generated by aut_sort_gens.  This can be set without sort_gens if characteristic
        aut_sort_conj, // an element conjugating subgroup to aut_sort_pick, in the Holomorph
        i, // can be negative during construction, but set to the index in subs when complete
        aut_label, // list of integers giving the automorphism part of the label
        full_label, // list of integers giving the full label
        label, // string giving the label (omitting the N.i from the group label)
        special_labels, // other labels (normal, maximal, special; omitting the N.i)
        unders, // other subs this sub contains maximally, as an associative array i->cnt, where i is the index in subs and cnt is the number of reps in that class contained in a single rep of this class
        overs, // other subs this sub is contained in minimally, in the same format
        mobius_sub, // value of the mobius subgroup function on this node of the lattice
        mobius_quo, // value of the mobius quotient function on this node of the lattice
        aut_unders, // as above, but up to automorphism
        aut_overs, // as above, but up to automorphism
        subgroup_count, // the number of subgroups in this conjugacy class of subgroups
        cc_count, // the number of conjugacy classes in this autjugacy class of subgroups
        recurse,
        standard_generators,
        gassman_vec, // for identification
        aut_gassman_vec, // for identification
        easy_hash, // for identification
        normalizer,
        centralizer,
        normal,
        characteristic,
        normal_closure,
        characteristic_closure;

declare type SubgroupLat;
declare attributes SubgroupLat:
        Grp,
        outer_equivalence,
        inclusions_known,
        subs,
        by_index,
        by_index_aut,
        conjugator,
        aut_class,
        aut_orbit,
        from_conj,
        aut_component_data,
        index_bound;

declare type SubgroupLatInterval;
declare attributes SubgroupLatInterval:
        Lat,
        top,
        bottom,
        subs,
        by_index;

declare type LMFDBSubgroupCache;
declare attributes LMFDBSubgroupCache:
        MagmaGrp,
        Subgroups,
        description, // a string usable to reconstruct the ambient group
        outer_equivalence, // true if up to automorphism
        labels, // a list of labels of subgroups
        gens, // a list of lists of elements generating the subgroups
        lengths, // a list of lengths (number of subgroups in the equivalence class)
        standard; // a list of booleans; whether the generators correspond to the standard generators for that abstract group

declare type LMFDBSubgroupCacheCollection;
declare attributes LMFDBSubgroupCacheCollection:
        cache;
subgroup_cache := New(LMFDBSubgroupCacheCollection);
subgroup_cache`cache := AssociativeArray();
// Add layer of indirection so that Magma lets us modify the cache
intrinsic GetSubgroupCacheCollection() -> LMFDBSubgroupCacheCollection
{}
    return subgroup_cache;
end intrinsic;

intrinsic GetGrp(C::LMFDBSubgroupCache) -> LMFDBGrp
{}
    G := New(LMFDBGrp);
    G`MagmaGrp := C`MagmaGrp;
    return G;
end intrinsic;

intrinsic LoadSubgroupCache(label::MonStgElt : sep:=":") -> LMFDBSubgroupCache
{}
    sgcache := GetSubgroupCacheCollection();
    if IsDefined(sgcache`cache, label) then
        return sgcache`cache[label];
    end if;
    C := New(LMFDBSubgroupCache);
    folder := GetLMFDBRootFolder();
    if #folder ne 0 then
        cache := folder * "SUBCACHE/" * label;
        ok, I := OpenTest(cache, "r");
        if ok then
            data := Read(I);
            data := Split(data, sep: IncludeEmpty := true);
            attrs := DefaultAttributes(LMFDBSubgroupCache);
            error if #data ne #attrs, "Wrong size data line";
            C`description := data[1];
            C`MagmaGrp := eval data[1];
            for i in [2..#attrs] do
                attr := attrs[i];
                C``attr := LoadAttr(attr, data[i], C);
            end for;
        end if;
    end if;
    sgcache`cache[label] := C;
    return C;
end intrinsic;

intrinsic SaveSubgroupCache(G::LMFDBGrp, subs::SeqEnum : sep:=":")
{We only save subgroup caches when complete (no index bound)}
    folder := GetLMFDBRootFolder();
    if #folder ne 0 then
        C := New(LMFDBSubgroupCache);
        C`outer_equivalence := G`outer_equivalence;
        C`description := description(G);
        C`labels := [H`label : H in subs];
        C`gens := [H`generators : H in subs];
        C`standard := [H`standard_generators : H in subs];
        data := SaveLMFDBObject(C : attrs := ["description", "labels", "gens", "standard"]);
        ok, I := OpenTest(folder * "SUBCACHE/" * G`label, "w");
        if ok then
            PrintFile(I, data);
        end if;
    end if;
end intrinsic;

intrinsic Valid(C::LMFDBSubgroupCache) -> BoolElt
{}
    return assigned C`description;
end intrinsic;

function SplitByAuts(L, G : use_order:=true, use_hash:=true, use_gassman:=false, aut:=true)
    // when aut is false we are using this function to group subgroups up to CONJUGACY,
    // in cases where the subgroups were iteratively found up to conjugacy inside a smaller group
    // than G
    // L is a list of lists of records or SubgroupLatElts, including `order and `subgroup
    // It should be closed under the action of the automorphism group
    // Gassman class is slow in holomorphs
    function check_done(M)
        return &and[#x eq 1 : x in M];
    end function;
    function get_easy_hash(x)
        if Type(x) eq Rec then return EasyHash(x`subgroup); end if;
        return Get(x, "easy_hash");
    end function;
    gvstr := aut select "aut_gassman_vec" else "gassman_vec";
    function get_gassman_vec(x)
        if Type(x) eq Rec then
            if gvstr eq "gassman_vec" then
                return SubgroupClass(x`subgroup, Get(G, "ClassMap"));
            else
                return SubgroupClass(x`subgroup, AutClassMap(G));
            end if;
        end if;
        return Get(x, gvstr);
    end function;
    if check_done(L) then return L; end if;
    if use_order then
        newL := [];
        for chunk in L do
            if #chunk gt 1 then
                newL cat:= [x : x in IndexFibers(chunk, func<s|s`order>)];
            else
                Append(~newL, chunk);
            end if;
        end for;
        L := newL;
        if check_done(L) then return L; end if;
    end if;
    if use_hash then
        newL := [];
        for chunk in L do
            if #chunk gt 1 then
                newL cat:= [x : x in IndexFibers(chunk, get_easy_hash)];
            else
                Append(~newL, chunk);
            end if;
        end for;
        L := newL;
        if check_done(L) then return L; end if;
    end if;
    if use_gassman then
        newL := [];
        for chunk in L do
            if #chunk gt 1 then
                newL cat:= [x : x in IndexFibers(chunk, get_gassman_vec)];
            else
                Append(~newL, chunk);
            end if;
        end for;
        L := newL;
        if check_done(L) then return L; end if;
    end if;
    newL := [];
    GG := G`MagmaGrp;
    Auts := 0; outs := 0; H := 0; inj := 0; // stupid Magma compiler requires these to be defined since used below
    if not aut then
        H := G`MagmaGrp;
        inj := IdentityHomomorphism(H);
        use_graph := false;
    elif Get(G, "HaveHolomorph") then
        H := Get(G, "Holomorph");
        inj := Get(G, "HolInj");
        use_graph := false;
    else
        Aut := Get(G, "MagmaAutGroup");
        outs := [f : f in Generators(Aut) | not IsInner(f)];
        use_graph := true;
    end if;
    for chunk in L do
        if #chunk gt 1 then
            if use_graph then
                edges := [{Integers()|} : _ in [1..#chunk]];
                for f in outs do
                    for i in [1..#chunk] do
                        H1 := chunk[i]`subgroup;
                        H2 := f(H1);
                        // check first if fixed by f, since this is common and means no edge
                        if IsConjugate(GG, H1, H2) then
                            continue;
                        end if;
                        found := false;
                        for j in [1..#chunk] do
                            if i ne j and IsConjugate(GG, H2, chunk[j]`subgroup) then
                                Include(~(edges[i]), j);
                                found := true;
                                break;
                            end if;
                        end for;
                        if not found then
                            error "subgroups not closed under automorphism";
                        end if;
                    end for;
                end for;
                V := Graph<#chunk| edges : SparseRep := true>;
                newL cat:= [[chunk[i] : i in Sort([Index(j) : j in comp])] : comp in Components(V)];
            else
                new_chunk := [];
                for s in chunk do
                    found := false;
                    j := 1;
                    while j le #new_chunk do
                        x := new_chunk[j];
                        if IsConjugate(H, inj(s`subgroup), inj(x[1]`subgroup)) then
                            found := true;
                            break;
                        end if;
                        j +:= 1;
                    end while;
                    if found then
                        Append(~new_chunk[j], s);
                    else
                        Append(~new_chunk, [s]);
                    end if;
                end for;
                newL cat:= new_chunk;
            end if;
        else
            Append(~newL, chunk);
        end if;
    end for;
    return newL;
end function;

intrinsic by_index(Lat::SubgroupLat) -> Assoc
{An associative array with integer keys and values the list of subgroups with that index}
    L := Lat`subs;
    n := (Lat`Grp)`order;
    AA := AssociativeArray();
    for j in [1..#L] do
        H := L[j];
        index := n div H`order;
        if not IsDefined(AA, index) then
            AA[index] := [];
        end if;
        Append(~AA[index], H);
    end for;
    return AA;
end intrinsic;

intrinsic by_index(Int::SubgroupLatInterval) -> Assoc
{An associative array with integer keys and values the list of subgroups with that index}
    L := Int`subs;
    n := Int`top`Lat`Grp`order;
    AA := AssociativeArray();
    for H in Int`subs do
        ind := n div H`order;
        if not IsDefined(AA, ind) then
            AA[ind] := [H];
        end if;
        Append(~AA[ind], H);
    end for;
    return AA;
end intrinsic;

intrinsic by_index_aut(L::SubgroupLat) -> Assoc
{}
    ans := AssociativeArray();
    for index -> subs in Get(L, "by_index") do
        if L`outer_equivalence then
            ans[index] := [[s] : s in subs];
        else
            ans[index] := SplitByAuts([subs], L`Grp : use_order:=false);
        end if;
    end for;
    return ans;
end intrinsic;

intrinsic aut_class(L::SubgroupLat) -> Assoc
{}
    bia := Get(L, "by_index_aut");
    ans := AssociativeArray();
    aut_orbit := AssociativeArray();
    for index -> aclasses in bia do
        for aclass in aclasses do
            orbit := [s`i : s in aclass];
            first := Min(orbit);
            for s in aclass do
                ans[s`i] := first;
                aut_orbit[s`i] := orbit;
            end for;
        end for;
    end for;
    L`aut_orbit := aut_orbit;
    return ans;
end intrinsic;

intrinsic aut_orbit(L::SubgroupLat) -> Assoc
{}
    _ := Get(L, "aut_class"); // Sets aut_orbit
    return L`aut_orbit;
end intrinsic;

intrinsic HaveHolomorph(X::LMFDBGrp) -> BoolElt
{Current implementation of Holomorph is as a permutation group of degree #G, which becomes infeasible as G grows}
    // Even for small groups, there may be cases where where the non-holomorph approach is faster.  Should profile
    return X`order lt 5000;
end intrinsic;

intrinsic HaveAutomorphisms(X::LMFDBGrp) -> BoolElt
{This variable controls whether we attempt to compute the automorphism group; it is true by default but can be set to false externally}
    return true;
end intrinsic;

intrinsic Holomorph(X::LMFDBGrp) -> Grp
{}
    error "Starting holomorph";
    G := X`MagmaGrp;
    A := Get(X, "MagmaAutGroup");
    H, inj := Holomorph(G, A);
    X`HolInj := inj;
    return H;
end intrinsic;

intrinsic HolInj(X::LMFDBGrp) -> HomGrp
{}
    _ := Holomorph(X); // computes the injection
    return X`HolInj;
end intrinsic;

intrinsic aut_component_data(L::SubgroupLat) -> Tuple
{Returns lookup, retract; where lookup[i] is the index i0 of the chosen subgroup in the same component as subs[i], and retract[i] is an automorphism mapping subs[i] to subs[i0]}
    subs := Get(L, "by_index_aut");
    subs := &cat[subs[n] : n in Sort([k : k in Keys(subs)])];
    lookup := AssociativeArray();
    retract := AssociativeArray();
    G := L`Grp;
    GG := G`MagmaGrp;
    Aut := Get(G, "MagmaAutGroup");
    outs := [f : f in Generators(Aut) | not IsInner(f)];
    t0 := Cputime();
    for i in [1..#subs] do
        print i, #subs, Cputime() - t0;
        comp := subs[i];
        for H in comp do
            lookup[H`i] := i;
        end for;
        retract[comp[1]`i] := Identity(Aut);
        seen := {1};
        layer := {1};
        while #seen lt #comp do
            new_layer := {};
            for j in layer do
                H := comp[j]`subgroup;
                for f in outs do
                    K := f(H);
                    for k in [2..#comp] do
                        if not (k in seen) then
                            conj, c := IsConjugate(GG, K, comp[k]`subgroup);
                            if conj then
                                fc := Aut!hom<GG -> GG | [g -> g^c : g in Generators(GG)]>;
                                Include(~seen, k);
                                Include(~new_layer, k);
                                retract[comp[k]`i] := fc^-1 * f^-1 * retract[comp[j]`i];
                            end if;
                        end if;
                    end for;
                end for;
            end for;
            assert #new_layer gt 0;
            layer := new_layer;
        end while;
    end for;
    return <lookup, retract>;
end intrinsic;

// As an alternative to the Holomorph, we can form a graph on the set of conjugacy classes (of elements or of subgroups) with edges given by the generators of the automorphism group, and then use connected components and geodesics
//
intrinsic IsAutjugateSubgroup(L::SubgroupLat, H1::Grp, H2::Grp) -> BoolElt, GrpElt
{Whether H1 and H2 are related by an automorphism, and an automorphism with f(H1) = H2 if they are}
    G := L`Grp;
    GG := G`MagmaGrp;
    A := Get(G, "MagmaAutGroup");
    if assigned L`from_conj then
        conjL, lookup := Explode(L`from_conj);
        b, c := IsAutjugateSubgroup(conjL, H1, H2);
        return b, c;
    elif L`outer_equivalence then
        Ambient := Get(G, "Holomorph");
        inj := Get(G, "HolInj");
        b, c := IsConjugateSubgroup(Ambient, inj(H1), inj(H2));
        if b then
            f := hom<GG -> GG | [g -> ((g @ inj)^c) @@ inj : g in Generators(GG)]>;
            return true, A!f;
        else
            return false, _;
        end if;
    end if;
    b1, i1, c1 := SubgroupIdentify(L, H1 : get_conjugator:=true); assert b1;
    b2, i2, c2 := SubgroupIdentify(L, H2 : get_conjugator:=true); assert b2;
    lookup, retract := Explode(Get(L, "aut_component_data"));
    i0 := lookup[i1]; i0x := lookup[i2];
    if i0 ne i0x then return false, _; end if;
    f1 := A!hom<GG -> GG | [g -> g^(c1^-1) : g in Generators(GG)]>;
    f2 := A!hom<GG -> GG | [g -> g^c2 : g in Generators(GG)]>;
    return true, f1 * retract[i1] * retract[i2]^-1 * f2;
end intrinsic;

intrinsic CCAutCollapse(X::LMFDBGrp) -> Map
{}
    CC := Get(X, "ConjugacyClasses");
    if Get(X, "HaveHolomorph") then
        Hol := Get(X, "Holomorph");
        inj := Get(X, "HolInj");
        D := Classify([1..#CC], func<i, j | IsConjugate(Hol, inj(CC[i]`representative), inj(CC[j]`representative))>);
    elif Get(X, "HaveAutomorphisms") then
        Aut := Get(X, "MagmaAutGroup");
        cm := Get(X, "ClassMap");
        outs := [f : f in Generators(Aut) | not IsInner(f)];
        edges := [{Integers()|} : _ in [1..#CC]];
        for f in outs do
            for i in [1..#CC] do
                j := cm(f(CC[i]`representative));
                if i ne j then
                    Include(~(edges[i]), j);
                end if;
            end for;
        end for;
        V := Graph<#CC| edges : SparseRep := true>;
        D := [Sort([Index(v) : v in comp]) : comp in Components(V)];
    else
        error "Must have either holomorph or automorphisms";
    end if;
    A := AssociativeArray();
    for i in [1..#D] do
        for j in [1..#D[i]] do
            A[D[i][j]] := i;
        end for;
    end for;
    return AssociativeArrayToMap(A, [1..#D]);
end intrinsic;

intrinsic AutClassMap(G::LMFDBGrp) -> Map
{}
    return Get(G, "ClassMap") * Get(G, "CCAutCollapse");
end intrinsic;

function SolvAutSubs(X : normal:=false)
    G := X`MagmaGrp;
    Ambient := Get(X, "Holomorph");
    inj := Get(X, "HolInj");
    GG := inj(G);
    E := ElementaryAbelianSeriesCanonical(G);
    EE := [inj(e) : e in E];
    subs := Subgroups(sub<GG|> : Presentation:=true);
    for i in [1..#EE-1] do
        subs := SubgroupsLift(Ambient, EE[i], EE[i+1], subs);
        if normal then
            subs := [S : S in subs | IsNormal(GG, sub<GG|S`subgroup, EE[i+1]>)];
        end if;
    end for;
    return [ rec< RF | subgroup := s`subgroup @@ inj, order := s`order> : s in subs ];
end function;

intrinsic is_sylow_order(X::LMFDBGrp, m::RngIntElt) -> BoolElt
{}
    N := Get(X, "order");
    // Apparently 1 is not a prime power in Magma
    return m eq 1 or IsPrimePower(m) and Gcd(m, N div m) eq 1;
end intrinsic;

intrinsic IsCharacteristic(G::LMFDBGrp, H::Grp) -> BoolElt
{Whether H is a characteristic subgroup of G (fixed under all automorphisms)}
    if Get(G, "HaveHolomorph") then
        Ambient := Get(G, "Holomorph");
        inj := Get(G, "HolInj");
        return IsNormal(Ambient, inj(H));
    else
        outs := [f : f in Generators(Get(G, "MagmaAutGroup")) | not IsInner(f)];
        return IsNormal(G`MagmaGrp, H) and &and[f(H) eq H : f in outs];
    end if;
end intrinsic;

intrinsic SubGrpLstAut(X::LMFDBGrp) -> SubgroupLat
    {The list of subgroups up to automorphism, cut off by an index bound if too many}
    G := X`MagmaGrp;
    N := Get(X, "order");
    trim := true;
    ordbd := 1;
    if Get(X, "solvable") and Get(X, "HaveHolomorph") then
        // In the most common case, we can use SubgroupsLift inside the holomorph to get autjugacy classes
        subs := SolvAutSubs(X);
        X`number_subgroup_autclasses := #subs;
        nchar := 0; nnorm := 0; nsubs := 0; nconj := 0;
        Ambient := Get(X, "Holomorph");
        inj := Get(X, "HolInj");
        for x in subs do
            acnt := Index(Ambient, Normalizer(Ambient, inj(x`subgroup)));
            if IsCharacteristic(X, x`subgroup) then nchar +:= 1; end if;
            nsubs +:= acnt;
            ccnt := Index(G, Normalizer(G, x`subgroup));
            if ccnt eq 1 then nnorm +:= acnt; end if;
            nconj +:= acnt div ccnt;
        end for;
        X`number_characteristic_subgroups := nchar;
        X`number_normal_subgroups := nnorm;
        X`number_subgroups := nsubs;
        X`number_subgroup_classes := nconj;
    else
        if AllSubgroupsOk(G) then
            // In this case, we compute all subgroups and then group them by autjugacy
            subs := Get(Get(X, "SubGrpLst"), "by_index_aut");
            subs := &cat[subs[n] : n in Sort([k : k in Keys(subs)])];
        else
            trim := false;
            // There may be too many subgroups, so we work by index
            D := Reverse(Divisors(N));
            subs := [];
            extra_subs := [];
            count := 0;
            for d in D do
                dsubs := Subgroups(G : OrderEqual := d);
                dsubs := SplitByAuts([dsubs], X : use_order := false);
                count +:= #dsubs;
                if count ge NUM_SUBS_CUTOFF_AUT then
                    break;
                elif count ge NUM_SUBS_LIMIT_AUT then
                    extra_subs cat:= dsubs;
                else
                    subs cat:= dsubs;
                end if;
            end for;
            if count lt NUM_SUBS_CUTOFF_AUT then
                subs cat:= extra_subs;
            end if;
            ordbd := subs[#subs]`order;
            if ordbd gt 1 then
                // Unlike the other two cases, we need to add in Sylow, normal and maximal subgroups
                X`number_subgroup_classes := None();
                X`number_subgroup_autclasses := None();
                X`number_subgroups := None();
                if X`sylow_subgroups_known then
                    for pe in Factorization(N) do
                        p := pe[1];
                        q := p^pe[2];
                        if q lt ordbd then
                            Append(~subs, [rec< RF | subgroup := SylowSubgroup(G, p), order := q >]);
                        end if;
                    end for;
                end if;
                if X`normal_subgroups_known then
                    Norms := NormalSubgroups(G);
                    X`number_normal_subgroups := #Norms;
                    if Get(X, "HaveHolomorph") or Get(X, "HaveAutomorphisms") then
                        X`number_characteristic_subgroups := #[H : H in Norms | IsCharacteristic(X, H : assume_normal:=true)];
                    else
                        X`number_characteristic_subgroups := None();
                    end if;
                    subs cat:= [[H] : H in Norms | H`order lt ordbd and not (X`sylow_subgroups_known and is_sylow_order(X, H`order))];
                else
                    X`number_normal_subgroups := None();
                    X`number_characteristic_subgroups := None();
                end if;
                if X`maximal_subgroups_known then
                    subs cat:= [[H] : H in MaximalSubgroups(G) | H`order lt ordbd and not (X`sylow_subgroups_known and is_sylow_order(X, H`order) or X`normal_subgroups_known and IsNormal(G, H))];
                end if;
            end if;
        end if;
        if ordbd eq 1 then
            X`number_subgroup_autclasses := #subs;
            nchar := 0; nnorm := 0; nsubs := 0; nconj := 0;
            norms := [cls : cls in subs | IsNormal(G, cls[1])];
            X`number_characteristic_subgroups := #[cls : cls in norms | #cls eq 1];
            X`number_normal_subgroups := &+[#cls : cls in norms];
            X`number_subgroup_classes := &+[#cls : cls in subs];
            X`number_subgroups := &+[&+[Index(G, Normalizer(G, H`subgroup)) : H in cls] : cls in subs];
        end if;
        subs := [x[1] : x in subs];
    end if;
    Sort(~subs, func<x, y | y`order - x`order>);
    if trim and #subs ge NUM_SUBS_CUTOFF_AUT then
        cut := NUM_SUBS_LIMIT_AUT - 1;
        while cut gt 0 and subs[cut]`order eq subs[NUM_SUBS_LIMIT_AUT]`order do
            cut -:= 1;
        end while;
        ordbd := subs[cut]`order;
        // We trim subgroups beyond the bound, keeping Sylow, normal and maximal ones
        if X`normal_subgroups_known then
            keep := {@ @};
        else
            keep := {@ i : i in [cut+1..#subs] | IsNormal(G, subs[i]`subgroup) @};
        end if;
        if X`sylow_subgroups_known then
            keep join:= {@ i : i in [cut+1..#subs] | is_sylow_order(X, subs[i]`order) @};
        end if;
        if X`maximal_subgroups_known then
            keep join:= {@ i : i in [cut+1..#subs] | IsMaximal(G, subs[i]`subgroup) @};
        end if;
        subs := subs[1..cut] cat [subs[i] : i in Sort(keep)];
    end if;
    res := New(SubgroupLat);
    res`Grp := X;
    res`outer_equivalence := true;
    res`inclusions_known := false;
    res`index_bound := (ordbd eq 1) select 0 else #G div ordbd;
    res`subs := [SubgroupLatElement(res, subs[i]`subgroup : i:=i) : i in [1..#subs]];
    AddSpecialSubgroups(res);
    return res;
end intrinsic;

intrinsic AddSpecialSubgroups(L::SubgroupLat)
{}
    G := L`Grp;
    GG := G`MagmaGrp;
    /* special groups labeled */
    Z := Center(GG);
    D := CommutatorSubgroup(GG);
    F := FittingSubgroup(GG);
    Ph := FrattiniSubgroup(GG);
    R := Radical(GG);
    So := Socle(G);  /* run special routine in case matrix group */

    // Add series
    Un := Reverse(UpperCentralSeries(GG));
    Ln := LowerCentralSeries(GG);
    Dn := DerivedSeries(GG);
    Cn := ChiefSeries(GG);
    /* all of the special groups are normal; we record which are characteristic as the last part of the tuple */
    SpecialGrps := [<Z,"Z",true>, <D,"D",true>, <F,"F",true>, <Ph,"Phi",true>, <R,"R",true>, <So,"S",true>, <Dn[#Dn],"PC",true>];
    Series := [<Un,"U",true>, <Ln,"L",true>, <Dn,"D",true>, <Cn,"C",false>];
    for tup in Series do
        for i in [1..#tup[1]] do
            H := tup[1][i];
            Append(~SpecialGrps, <H, tup[2]*Sprint(i-1), tup[3]>);
        end for;
    end for;

    for tup in SpecialGrps do
        // Check if we have the subgroup, and just need to add the special label
        conj, i, elt := SubgroupIdentify(L, tup[1] : get_conjugator:=true, use_gassman:=false, characteristic:=tup[3]);
        if conj then
            Append(~L`subs[i]`special_labels, tup[2]);
        else
            H := SubgroupLatElement(L, tup[1] : i:=#L`subs+1, normalizer:=1);
            Append(~H`special_labels, tup[2]);
            Append(~L`subs, H);
        end if;
    end for;
end intrinsic;

intrinsic SubgroupLatElement(L::SubgroupLat, H::Grp : i:=false, normalizer:=false, centralizer:=false, normal:=0, normal_closure:=false, gens:=false, subgroup_count:=false, standard:=false, recurse:=0) -> SubgroupLatElt
{}
    x := New(SubgroupLatElt);
    x`Lat := L;
    x`subgroup := H;
    x`order := #H;
    x`special_labels := [];
    x`standard_generators := standard;
    if L`inclusions_known then
        x`overs := AssociativeArray();
        x`unders := AssociativeArray();
    end if;
    if Type(i) ne BoolElt then x`i := i; end if;
    if Type(normalizer) ne BoolElt then x`normalizer := normalizer; end if;
    if Type(centralizer) ne BoolElt then x`centralizer := centralizer; end if;
    if Type(normal_closure) ne BoolElt then x`normal_closure := normal_closure; end if;
    if Type(gens) ne BoolElt then x`gens := gens; end if;
    if Type(subgroup_count) ne BoolElt then x`subgroup_count := subgroup_count; end if;
    if Type(normal) ne RngIntElt then x`normal := normal; end if;
    if Type(recurse) ne RngIntElt then x`recurse := recurse; end if;
    return x;
end intrinsic;

intrinsic gassman_vec(x::SubgroupLatElt) -> SeqEnum
{}
    L := x`Lat;
    if L`outer_equivalence then
        return Get(x, "aut_gassman_vec");
    end if;
    return SubgroupClass(x`subgroup, Get(L`Grp, "ClassMap"));
end intrinsic;
intrinsic aut_gassman_vec(x::SubgroupLatElt) -> SeqEnum
{}
    return SubgroupClass(x`subgroup, AutClassMap(x`Lat`Grp));
end intrinsic;
intrinsic easy_hash(x::SubgroupLatElt) -> RngIntElt
{}
    return EasyHash(x`subgroup);
end intrinsic;

function gvec_le(a, b)
    // determine whether the gassman vectors of two subsets are compatible with an inclusion
    // a and b are sorted lists of pairs [k,v] where k is a conjugacy class index and v is a count of elements in that class
    ai := 1;
    bi := 1;
    while bi le #b do
        if a[ai][1] eq b[bi][1] then
            if a[ai][2] gt b[bi][2] then
                return false;
            end if;
            ai +:= 1;
            bi +:= 1;
            if ai gt #a then
                return true; // We've seen all the entries of a
            end if;
        elif a[ai][1] gt b[bi][1] then
            // entry of b was missing in a; that's fine
            bi +:= 1;
        else
            // entry of a was missing in b, so a cannot be a subset
            return false;
        end if;
    end while;
    // We've reached the end of b, but not of a (otherwise the ai gt #a clause would have triggered)
    return false;
end function;

intrinsic SubgroupIdentify(L::SubgroupLat, H::Grp : use_hash:=true, use_gassman:=true, get_conjugator:=false, characteristic:=false) -> Any
{}
//Determines the index of a given subgroup among the elements of a SubgroupLat.
//Does not require by_index, subgroup_count, overs or unders on the elements to be set.
//If get_conjugator is true, returns three things: is_conj, i, conjugating element
//Otherwise, just returns i and raises an error if not found
    if assigned L`from_conj and not get_conjugator then
        // constructed from another lattice up to conjugacy, where we can more easily identify subgroups
        conjL, lookup := Explode(L`from_conj);
        return lookup[SubgroupIdentify(conjL, H : use_hash:=use_hash, use_gassman:=use_gassman, characteristic:=characteristic)];
    end if;
    G := L`Grp`MagmaGrp;
    ind := #G div #H;
    by_index := Get(L, "by_index");
    if not IsDefined(by_index, ind) then
        if get_conjugator then
            return false, 0, Identity(G);
        else
            error "Subgroup not found";
        end if;
    end if;
    poss := by_index[#G div #H];
    if L`outer_equivalence then
        Ambient := Get(L`Grp, "Holomorph");
        inj := Get(L`Grp, "HolInj");
        cmap := AutClassMap(L`Grp);
        gtype := "aut_gassman_vec";
    else
        Ambient := G;
        inj := IdentityHomomorphism(G);
        cmap := Get(L`Grp, "ClassMap");
        gtype := "gassman_vec";
    end if;
    Hi := (Type(H) eq GrpPerm and H subset Ambient) select H else inj(H);
    function finish(ans, compconj)
        if compconj then
            K := ans`subgroup;
            Ki := (Type(K) eq GrpPerm and K subset Ambient) select K else inj(K);
            conj, elt := IsConjugate(Ambient, Ki, Hi);
            if conj then
                return conj, ans`i, elt;
            else
                return false, 0, Identity(G);
            end if;
        end if;
        return ans`i;
    end function;
    if #poss eq 1 then
        return finish(poss[1], get_conjugator);
    end if;
    if characteristic then
        // we can just use equality testing
        for HH in poss do
            if HH`subgroup eq H then
                return finish(HH, get_conjugator);
            end if;
        end for;
    else
        if use_hash then
            refined := [];
            hsh := EasyHash(H);
            for j in [1..#poss] do
                HH := poss[j];
                HHhsh := Get(HH, "easy_hash");
                if HHhsh eq hsh then
                    Append(~refined, HH);
                end if;
            end for;
            if #refined eq 1 then
                return finish(refined[1], get_conjugator);
            end if;
            poss := refined;
        end if;
        if use_gassman then
            refined := [];
            old_poss := poss;
            if (Type(H) eq GrpPerm and H subset Ambient) then
                gvec := SubgroupClass(H@@inj, cmap);
            else
                gvec := SubgroupClass(H, cmap);
            end if;
            for j in [1..#poss] do
                HH := poss[j];
                HHvec := Get(HH, gtype);
                if HHvec eq gvec then
                    Append(~refined, HH);
                end if;
            end for;
            if #refined eq 1 then
                return finish(refined[1], get_conjugator);
            end if;
            poss := refined;
        end if;
        for HH in poss do
            conj, i, elt := finish(HH, true);
            if conj then
                if get_conjugator then
                    return true, i, elt;
                else
                    return i;
                end if;
            end if;
        end for;
    end if;
    if get_conjugator then
        return false, 0, Identity(G);
    end if;
    error "Subgroup not found", poss, gvec, [Get(HH, "gassman_vec") : HH in old_poss];
end intrinsic;

intrinsic 'eq'(x::SubgroupLatElt, y::SubgroupLatElt) -> BoolElt
{}
    return x`i eq y`i and x`Lat cmpeq y`Lat;
end intrinsic;
intrinsic IsCoercible(Lat::SubgroupLat, i::RngIntElt) -> BoolElt, SubgroupLatElt
{}
    return (0 lt i and i le #Lat`subs), Lat`subs[i];
end intrinsic;
intrinsic IsCoercible(Lat::SubgroupLat, H::Grp) -> BoolElt, SubgroupLatElt
{}
    if H subset (Lat`Grp`MagmaGrp) then
        return true, Lat`subs[SubgroupIdentify(Lat, H)];
    end if;
    return false;
end intrinsic;
intrinsic Print(x::SubgroupLatElt)
{}
    printf "%o", x`i;
end intrinsic;
intrinsic Print(Lat::SubgroupLat)
{}
    lines := ["Partially ordered set of subgroup classes",
              "-----------------------------------------",
              ""];
    if Lat`outer_equivalence then
        lines[1] *:= " up to automorphism";
    else
        lines[1] *:= " up to conjugacy";
    end if;
    n := Get(Lat`Grp, "order");
    by_index := Get(Lat, "by_index");
    for d in Sort([k : k in Keys(by_index)]) do
        m := n div d;
        for H in by_index[d] do
            if Lat`inclusions_known then
                Append(~lines, Sprintf("[%o]  Order %o  Length %o  Maximal Subgroups: %o", H`i, m, H`subgroup_count, Join([Sprint(u) : u in Sort([j : j in Keys(H`unders)])], " ")));
            else
                Append(~lines, Sprintf("[%o]  Order %o  Length %o", H`i, m, H`subgroup_count));
            end if;
        end for;
    end for;
    printf Join(lines, "\n");
end intrinsic;
intrinsic '#'(L::SubgroupLat) -> RngIntElt
{}
    return #L`subs;
end intrinsic;
/*intrinsic '[]'(Lat::SubgroupLat, i::RngIntElt) -> SubgroupLatElt
{}
    return Lat`subs[i];
end intrinsic;*/

intrinsic Empty(I::SubgroupLatInterval) -> BoolElt
{}
    return #I`subs eq 0;
end intrinsic;

function half_interval(x, dir, D)
    Lat := x`Lat;
    nodes := [x];
    done := 0;
    seen := {x`i};
    while done lt #nodes do
        done +:= 1;
        for m in Keys(Get(nodes[done], dir)) do
            H := Lat`subs[m];
            if (#D eq 0 or H`order in D) and not H`i in seen then
                Include(~seen, H`i);
                Append(~nodes, H);
            end if;
        end for;
    end while;
    return seen;
end function;

intrinsic HalfInterval(x::SubgroupLatElt : dir:="unders", D:={}) -> SubgroupLatInterval
{Nonempty D will short-circuit the breadth-first search by stopping if the order of a node is not in D.}
    I := New(SubgroupLatInterval);
    Lat := x`Lat;
    n := Get(Lat`Grp, "order");
    I`Lat := Lat;
    I`top := dir eq "unders" select x else Lat`subs[1];
    I`bottom := dir eq "unders" select Lat`subs[#Lat] else x;
    I`subs := [Lat`subs[i] : i in half_interval(x, dir, D)];
    return I;
end intrinsic;

intrinsic Interval(top::SubgroupLatElt, bottom::SubgroupLatElt : downward:={}, upward:={}) -> SubgroupLatInterval
{}
    if not top`Lat cmpeq bottom`Lat then
        error "elements must belong to the same lattice";
    end if;
    I := New(SubgroupLatInterval);
    Lat := top`Lat;
    n := Get(Lat`Grp, "order");
    I`Lat := Lat;
    I`top := top;
    I`bottom := bottom;
    D := {d : d in Divisors(top`order) | IsDivisibleBy(d, bottom`order)};
    if #downward eq 0 then downward := half_interval(top, "unders", D); end if;
    if #upward eq 0 then upward := half_interval(bottom, "overs", D); end if;
    I`subs := [Lat`subs[i] : i in downward meet upward];
    return I;
end intrinsic;

intrinsic 'ge'(x::SubgroupLatElt, y::SubgroupLatElt) -> BoolElt
{}
    // Not all the work for Interval is necessary, but this is simple
    // we short-circuit the case that x==y for speed
    return x`i eq y`i or not Empty(Interval(x, y));
end intrinsic;
intrinsic 'gt'(x::SubgroupLatElt, y::SubgroupLatElt) -> BoolElt
{}
    return x`i ne y`i and not Empty(Interval(x, y));
end intrinsic;
intrinsic 'le'(x::SubgroupLatElt, y::SubgroupLatElt) -> BoolElt
{}
    return x`i eq y`i or not Empty(Interval(y, x));
end intrinsic;
intrinsic 'lt'(x::SubgroupLatElt, y::SubgroupLatElt) -> BoolElt
{}
    return x`i ne y`i and not Empty(Interval(y, x));
end intrinsic;

intrinsic Print(I::SubgroupLatInterval)
{}
    printf "%o->%o", I`top, I`bottom;
end intrinsic;

intrinsic NumberOfInclusions(x::SubgroupLatElt, y::SubgroupLatElt) -> RngIntElt
{The number of elements of the conjugacy class of subgroups x that lie in a fixed representative of the conjugacy class of subgroups y}
    if x`i eq y`i then return 1; end if;
    G := x`Lat`Grp;
    if x`Lat`outer_equivalence then
        Ambient := Get(G, "Holomorph");
        inj := Get(G, "HolInj");
    else
        Ambient := G`MagmaGrp;
        inj := IdentityHomomorphism(G`MagmaGrp);
    end if;
    c := x`Lat`conjugator[[x`i, y`i]];
    H := inj(y`subgroup);
    K := inj(x`subgroup)^c;
    NH := Normalizer(Ambient, H);
    NK := Normalizer(Ambient, K);
    if #NK ge #NH then
        return #[1: g in RightTransversal(Ambient, NK) | K^g subset H];
    else
        ind := #[1: g in RightTransversal(Ambient, NH) | K subset H^g];
        assert IsDivisibleBy(ind * Get(x, "subgroup_count"), Get(y, "subgroup_count"));
        return ind * x`subgroup_count div y`subgroup_count;
    end if;
    /*
    // Unfortunately, this is not correct since it's possible to have elements of G that map K into H but don't normalize H.
    NH := Normalizer(Ambient, H);
    NK := Normalizer(Ambient, K);
    return Index(NH, NH meet NK);
    */
    //return #[J : J in Conjugates(Ambient, K) | J subset H];
end intrinsic;

// Implementation adapted from Magma's Groups/GrpFin/subgroup_lattice.m
function ms(G)
    M := MaximalSubgroups(G);
    if Type(M[1]) eq Rec then return M; end if;
    res := [];
    for K in M do
	N := Normalizer(G,K);
	L := Index(G,N);
	r := rec<RF|subgroup := K, order := #K, length := L>;
	Append(~res, r);
    end for;
    return res;
end function;
// It would be better to use SubgroupLift with a Maximal option
function maximal_subgroup_classes(G, H, aut : collapse:=true)
    // Ambient = G or Holomorph(G)
    // H is a subgroup of G
    // inj is the map from G to Ambient
    // N is the normalizer of H inside Ambient
    // Returns a list of records giving maximal subgroups of H up to conjugacy in Ambient; if collapse then guaranteed to be inequivalent
    if aut then
        Ambient := Get(G, "Holomorph");
        inj := Get(G, "HolInj");
    else
        Ambient := G`MagmaGrp;
        inj := IdentityHomomorphism(G`MagmaGrp);
    end if;
    if IsTrivial(H) then return []; end if;
    function do_collapse(results)
        if collapse then
            results := SplitByAuts([results], G);
            return [rec<RF|subgroup:=r[1]`subgroup, order:=r[1]`order, length:=&+[x`length : x in r]> : r in results];
        else
            return results;
        end if;
    end function;
    if #FactoredOrder(H) gt 1 then
        return do_collapse(ms(H));
    end if;
    Hi := inj(H);
    N := Normalizer(Ambient, Hi);
    if N eq Ambient then
        return do_collapse(ms(H));
    end if;
    F := FrattiniSubgroup(H);
    Fi := inj(F);
    M, f := GModule(N, Hi, Fi);
    f := inj * f;
    d := Dimension(M) - 1;
    p := #BaseRing(M);
    ord := #H div p;
    orbs := OrbitsOfSpaces(ActionGroup(M), d);
    res := [];
    for o in orbs do
	K := sub<H|F, [(M!o[2].i)@@f:i in [1..d]]>;
	if Type(K) in {GrpPerm, GrpMat} then
	    K`Order := ord;
	end if;
	Append(~res, rec<RF|subgroup := K, order := ord, length := o[1]>);
    end for;
    return res; // already collapsed
end function;

/*
This method for computing the subgroup lattice was superceded by SubgroupLattice_edges
function SubgroupLattice(GG, aut)
    Lat := New(SubgroupLat);
    Lat`Grp := GG;
    Lat`outer_equivalence := aut;
    Lat`inclusions_known := true;
    Lat`index_bound := 0;
    // May want to double check that GG`subgroup_inclusions_known=true and/or GG`subgroup_index_bound=0
    G := GG`MagmaGrp;
    solv := Get(GG, "solvable");
    if solv then
        // Hall's theorem
        singleton_indexes := {d : d in Divisors(#G) | Gcd(d, #G div d) eq 1};
    elif #Factorization(#G) gt 1 then
        // On Hall subgroups of a finite group
        // Wenbin Guo and Alexander Skiba
        CS := ChiefSeries(G);
        indexes := [#CS[i] div #CS[i+1] : i in [1..#CS-1]];
        singleton_indexes := {};
        for d in Divisors(#G) do
            if Gcd(d, #G div d) eq 1 and &and[IsDivisibleBy(d, ind) or IsDivisibleBy(#G div d, ind) : ind in indexes] then
                Include(~singleton_indexes, d);
            end if;
        end for;
    else
        singleton_indexes := {1, #G};
    end if;
    if aut then
        Ambient := Get(GG, "Holomorph");
        inj := Get(GG, "HolInj");
    else
        Ambient := G;
        inj := IdentityHomomorphism(G);
    end if;
    collapsed := []; // contains one SubgroupLatElt from each equivalence class, ordered by index
    top := SubgroupLatElement(Lat, sub<G|G> : i:=1, normal_closure:=1);
    Append(~collapsed, top);
    Mlist := maximal_subgroup_classes(GG, G, aut : collapse:=true);
    maximals := AssociativeArray();
    to_add := AssociativeArray(); // groups that could have repetitions still
    tmp_indexes := AssociativeArray(); // when we add a group from the cache, we record inclusion counts
    tmp_index_base := 0;
    for d in Divisors(#G) do
        to_add[d] := [];
        maximals[d] := [];
    end for;
    for M in Mlist do
        Append(~maximals[#G div M`order], M);
    end for;
    for d in Divisors(#G) do
        // Maximal subgroups have already been added to collapsed, so we process them first, adding more subgroups to to_add
        if d eq 1 then continue; end if; // already added G
        for MM in maximals[d] do
            M := MM`subgroup;
            lab := label(M);
            //cache := LoadSubgroupCache(lab);
            cache := false; // here for magma's compiler
            if false then // Valid(cache) then // until the bugs in automorphism groups are worked around, we only save caches where outer_equivalence is false
                ok, phi := IsIsomorphic(cache`MagmaGrp, M);
                if not ok then
                    error Sprintf("Lack of isomorphism: %s for %s < %s", lab, Generators(M), GG`label);
                end if;

                // The equivalence relation for subgroups in the cache is not the one desired.  It's okay if there are duplicates (this will be cleaned up below), but we need to ensure that we hit all the classes.
                // If the subgroups in the cache are up to conjugacy, we're fine
                // Otherwise, let A_G = Holomorph(G) or G, A_M = Aut(M) and H_M = Holomorph(M)
                // N_{A_G}(M) -> A_M -> H_M / N_{H_M}(H).  A transversal of the image will give *inequivalent* reps coming from H
                if cache`outer_equivalence then // shouldn't currently trigger
                    error "Need to work around Magma bugs";
                    NM := Normalizer(Ambient, inj(M));
                    AM := Type(M) eq GrpPC select AutomorphismGroupSolubleGroup(M) else AutomorphismGroup(M);
                    HM, injM, projM := Holomorph(M, AM);
                    SM := sub<AM | [hom<M -> M | [m -> (inj(m)^f) @@ inj : m in Generators(M)]> : f in Generators(NM)]>;
                    // This doesn't work since Magma can't seem to compute preimages under proj
                    //SM := SM @@ projM;
                    // This doesn't work: it gives a runtime error in the hom constructor, even though f@@projM fixes 1 and thus should be in the complement of M specified in the docs
                    //projMinv := hom<AM -> HM | [f -> (f @@ projM) : f in Generators(M)]>;
                    // We work around it as follows
                    AMFP, fromFP := FPGroup(AM);
                    tmp := hom<AMFP -> HM | [f -> (fromFP(f) @@ projM) : f in Generators(AMFP)]>;
                    projMinv := Inverse(fromFP) * tmp;
                    // This fails
                    //auts_from_G := SM @ projMinv;
                    auts_from_G := sub<HM | [injM(m) : m in Generators(M)] cat [projMinv(f) : f in Generators(SM)]>;
                    // Now for any subgroup H of M, a transversal of HM / <auts_from_G, Normalizer(HM, H)> gives subgroups of G that are not autjugate...
                else
                    for j in [1..#cache`gens] do
                        // Todo: make sure we don't add M again
                        gens := [phi(g) : g in cache`gens[j]];
                        H := sub<G | gens>;
                        HH := SubgroupLatElement(Lat, H : i:=tmp_index_base - j, gens:=gens, standard:=cache`standard[j], recurse:=false);
                        // Need to add overs from cache, with weights
                        for pair in cache`overs do
                            HH`overs[tmp_index_base - pair[1]] := pair[2];
                        end for;
                        Append(~to_add[#G div #H], HH);
                    end for;
                    tmp_index_base -:= #cache`gens;
                end if;
            else // cache not saved
                HH := SubgroupLatElement(Lat, M : gens:=Generators(M), recurse:=true);
                HH`overs[1] := MM`length;
                Append(~to_add[#G div #M], HH);
            end if;
            //Append(~collapsed[H`order],
        end for;
        if #to_add[d] eq 0 then continue; end if; // no subgroups of this index
        this_index := [to_add[d]];
        if not d in singleton_indexes then
            this_index := SplitByAuts(this_index, GG : use_order:=false);
        end if;
        for cluster in this_index do
            // combine overs: just add weights
            H := cluster[1];
            Append(~collapsed, H);
            if assigned H`i then
                tmp_indexes[H`i] := #collapsed;
            end if;
            H`i := #collapsed;
            for k -> cnt in H`overs do
                if k lt 0 then // temp label
                    Remove(H`overs, k);
                    H`overs[tmp_indexes[k]] := cnt;
                end if;
            end for;
            for j in [2..#cluster] do
                K := cluster[j];
                if assigned K`i then
                    tmp_indexes[K`i] := #collapsed;
                end if;
                for k -> cnt in K`overs do
                    if k lt 0 then // temp label
                        kpos := tmp_indexes[k];
                    else
                        kpos := k;
                    end if;
                    if IsDefined(H`overs, kpos) then
                        H`overs[kpos] +:= cnt;
                    else
                        H`overs[kpos] := cnt;
                    end if;
                end for;
                if K`standard_generators and not H`standard_generators then
                    H`gens := K`gens;
                end if;
            end for;
            if &and[HH`recurse : HH in cluster] then
                for K in maximal_subgroup_classes(GG, H`subgroup, aut : collapse:=false) do
                    KK := SubgroupLatElement(Lat, K`subgroup : gens:=[G!g : g in Generators(K`subgroup)], recurse:=true);
                    KK`overs[#collapsed] := K`length;
                    Append(~to_add[#G div K`order], KK);
                end for;
            end if;
        end for;
    end for;
    Lat`subs := collapsed;
    // Set the counts
    for j in [1..#collapsed] do
        HH := collapsed[j];
        H := HH`subgroup;
        N := Normalizer(Ambient, inj(H));
        HH`subgroup_count := Index(Ambient, N);
        if aut then
            N := Normalizer(G, H);
            HH`cc_count := HH`subgroup_count div Index(G, N);
        else
            HH`cc_count := 1;
        end if;
        HH`normalizer := SubgroupIdentify(Lat, N);
        HH`centralizer := SubgroupIdentify(Lat, Centralizer(G, H));
        current_layer := {HH};
        while not HasAttribute(HH, "normal_closure") do
            next_layer := {};
            for cur in current_layer do
                if cur`cc_count eq cur`subgroup_count then // normal
                    HH`normal_closure := cur`i;
                    break;
                end if;
                for next in Keys(cur`overs) do
                    Include(~next_layer, Lat`subs[next]);
                end for;
            end for;
            current_layer := next_layer;
        end while;
        for k -> v in HH`overs do
            KK := collapsed[k];
            KK`unders[HH`i] := KK`subgroup_count*v div HH`subgroup_count;
        end for;
    end for;
    AddSpecialSubgroups(Lat); // just adds the labels since the subgroups already present
    return Lat;
end function;
*/

procedure ComputeLatticeEdges(~L, Ambient, inj : normal_lattice:=false)
    one := Identity(Ambient);
    n := L`Grp`order;
    C := AssociativeArray();
    overs := [{Integers()|} : i in [1..#L]];
    unders := [{Integers()|} : i in [1..#L]];
    // We start by adding all edges with prime order
    function prime_count(m)
        return m eq 1 select 0 else &+[pair[2] : pair in Factorization(m)];
    end function;
    pcn := prime_count(n);
    by_index := Get(L, "by_index");
    by_ndiv := IndexFibers([k : k in Keys(by_index)], prime_count);
    known_below := AssociativeArray();
    known_above := AssociativeArray();
    for i in [1..#L] do
        known_below[i] := {i};
        known_above[i] := {i};
    end for;
    //D := Reverse(Sort([k : k in Keys(by_index)]));
    //print "D", D;

    procedure add_edge(~CC, ~kb, ~ka, ~new_edges, bottom, mid, top)
        if not IsDefined(CC, [bottom, top]) then
            //print "Adding", bottom, mid, top;
            if normal_lattice then
                CC[[bottom, top]] := true;
            else
                if CC[[bottom, mid]] eq one and CC[[mid, top]] eq one then
                    CC[[bottom, top]] := one;
                elif L`subs[bottom]`subgroup subset L`subs[top]`subgroup then
                    // We want use use one whenever possible
                    CC[[bottom, top]] := one;
                else
                    CC[[bottom, top]] := CC[[bottom, mid]] * CC[[mid, top]];
                end if;
            end if;
            Include(~kb[top], bottom);
            Include(~ka[bottom], top);
            Append(~new_edges, [bottom, top]);
        end if;
    end procedure;
    procedure propogate_edges(~CC, ~kb, ~ka, edges)
        // Recursively propogate the addition of some edges to fill in all relevant new comparisons in C
        vprint User1: #edges, "edges";
        while #edges gt 0 do
            new_edges := [];
            for edge in edges do
                for bottom in kb[edge[1]] do
                    add_edge(~CC, ~kb, ~ka, ~new_edges, bottom, edge[1], edge[2]);
                end for;
                for top in ka[edge[2]] do
                    add_edge(~CC, ~kb, ~ka, ~new_edges, edge[1], edge[2], top);
                end for;
            end for;
            edges := new_edges;
        end while;
    end procedure;

    for len in [1..pcn] do
        vprint User1: Sprintf("Adding length %o edges", len);
        new_edges := [];
        for base_cnt in [pcn..len by -1] do // number of divisors of index for subgroup
            top_cnt := base_cnt - len; // number of divisors of index for supergroup
            if not (IsDefined(by_ndiv, base_cnt) and IsDefined(by_ndiv, top_cnt)) then continue; end if;
            for d in by_ndiv[base_cnt] do
                M := [m : m in by_ndiv[top_cnt] | IsDivisibleBy(d, m)];
                for sub in by_index[d] do
                    subvec := Get(sub, "gassman_vec");
                    for m in M do
                        for super in by_index[m] do
                            if IsDefined(C, [sub`i, super`i]) then continue; end if;
                            supervec := Get(super, "gassman_vec");
                            if gvec_le(subvec, supervec) then
                                if normal_lattice then
                                    // Normal subgroup inclusion is determined by gassman_vec comparison
                                    conj := true; elt := true;
                                else
                                    conj, elt := IsConjugateSubgroup(Ambient, inj(super`subgroup), inj(sub`subgroup));
                                end if;
                                if conj then
                                    C[[sub`i, super`i]] := elt;
                                    Include(~known_below[super`i], sub`i);
                                    Include(~known_above[sub`i], super`i);
                                    Append(~new_edges, [sub`i, super`i]);
                                    Include(~overs[sub`i], super`i);
                                    Include(~unders[super`i], sub`i);
                                //    print "Including", sub`i, super`i;
                                //else
                                //    print "Not including", sub`i, super`i;
                                end if;
                            end if;
                        end for;
                    end for;
                end for;
            end for;
        end for;
        propogate_edges(~C, ~known_below, ~known_above, new_edges);
        vprint User1: Sprintf("Length %o edges added", len);
    end for;
    L`conjugator := C;
    for i in [1..#L] do
        // For now we switch to AssociativeArrays for compatibility with the old code
        //L`subs[i]`overs := overs[i];
        L`subs[i]`overs := AssociativeArray();
        for j in overs[i] do
            L`subs[i]`overs[j] := true;
        end for;
        //L`subs[i]`unders := unders[i];
        L`subs[i]`unders := AssociativeArray();
        for j in unders[i] do
            L`subs[i]`unders[j] := true;
        end for;
    end for;
end procedure;

intrinsic normal(H::SubgroupLatElt) -> BoolElt
{Whether this subgroup is normal}
    return Get(H, "cc_count") eq Get(H, "subgroup_count");
end intrinsic;

intrinsic characteristic(H::SubgroupLatElt) -> BoolElt
{Whether this subgroup is stabilized by all automorphisms}
    L := H`Lat;
    return Get(H, "subgroup_count") eq 1 and (L`outer_equivalence or #Get(L, "aut_orbit")[H`i] eq 1);
end intrinsic;

procedure SetClosures(~L)
    // Set normal and characteristic closures
    L`subs[1]`normal_closure := 1;
    L`subs[1]`characteristic_closure := 1;
    for j in [2..#L] do
        HH := L`subs[j];
        for attr in ["normal_closure", "characteristic_closure"] do
            if assigned HH``attr then continue; end if;
            current_layer := {HH};
            to_assign := {HH};
            while not HasAttribute(HH, attr) do
                next_layer := {};
                for cur in current_layer do
                    if (attr eq "normal_closure" and Get(cur, "normal")
                        or attr eq "characteristic_closure" and Get(cur, "characteristic")) then
                        // The following doesn't work because Magma is stupid
                        /*for H in to_assign do
                            H``attr := cur`i;
                        end for;*/
                        to_assign := [H : H in to_assign];
                        for k in [1..#to_assign] do
                            to_assign[k]``attr := cur`i;
                        end for;
                        break;
                    end if;
                    for next in Keys(Get(cur, "overs")) do
                        Include(~next_layer, L`subs[next]);
                    end for;
                end for;
                to_assign join:= current_layer;
                current_layer := next_layer;
            end while;
        end for;
    end for;
end procedure;

/*AttachSpec("spec");
SetVerbose("User1", 1);
G := MakeBigGroup("40T6148", "10240.gz");
G`all_subgroups_known := true;
G`subgroup_index_bound := 0;
G`maximal_subgroups_known := true;
G`subgroup_inclusions_known := true;
G`normal_subgroups_known := true;
G`sylow_subgroups_known := true;
X := PrintData(G);

Fix number_characteristic_subgroups, number_normal_subgroups, number_subgroup_autclasses, number_subgroup_classes, number_subgroups (currently set in SubGrpLstAut, but this was only called when determining blah values)
Set pc_code, permutation_degree, representations externally
*/
function SubgroupLattice_edges(G, aut)
    // This version of SubgroupLattice constructs the subgroups first then adds edges
    GG := G`MagmaGrp;
    vprint User1: "Starting to list subgroups with aut =", aut;
    if aut then
        L := Get(G, "SubGrpLstAut");
        Ambient := Get(G, "Holomorph");
        inj := Get(G, "HolInj");
    else
        L := Get(G, "SubGrpLst");
        Ambient := GG;
        inj := IdentityHomomorphism(GG);
    end if;
    ComputeLatticeEdges(~L, Ambient, inj);
    vprint User1: "Setting normal and characteristic closures";
    SetClosures(~L);
    vprint User1: "Setting mobius_sub";
    // Set the mobius functions
    L`subs[1]`mobius_sub := 1; //μ_G(G) = 1
    noi := AssociativeArray();
    for i in [2..#L] do
        x := L`subs[i];
        x`mobius_sub := 0;
        //print "x", x`i;
        for j in half_interval(x, "overs", {}) do
            y := L`subs[j];
            if x`i eq y`i then continue; end if;
            n := NumberOfInclusions(x, y);
            if Get(x, "subgroup_count") eq Get(x, "cc_count") and Get(y, "subgroup_count") eq Get(y, "cc_count") then // both normal
                noi[[x`i,y`i]] := n;
            end if;
            //print x`i, y`i, y`subgroup_count, n, y`mobius_sub, x`subgroup_count;
            x`mobius_sub -:= (y`subgroup_count * n * y`mobius_sub) div x`subgroup_count;
        end for;
        //print "mobius_sub", x`mobius_sub;
    end for;
    vprint User1: "Setting mobius_quo";
    if L`index_bound eq 0 then
        L`subs[#L]`mobius_quo := 1;
        for i in [#L-1..1 by -1] do
            x := L`subs[i];
            if x`subgroup_count eq x`cc_count then
                x`mobius_quo := 0;
                for j in half_interval(x, "unders", {}) do
                    y := L`subs[j];
                    if x`i eq y`i or y`subgroup_count ne y`cc_count then continue; end if;
                    x`mobius_quo -:= noi[[y`i, x`i]] * y`mobius_quo;
                end for;
            else
                x`mobius_quo := None();
            end if;
        end for;
    end if;
    vprint User1: "Mobius function computed";
    L`inclusions_known := true;
    return L;
end function;

intrinsic SubGrpLst(G::LMFDBGrp) -> SubgroupLat
{The list of all subgroups up to conjugacy}
    // For now, we start with index 1 rather than order 1
    subs := Reverse(Subgroups(G`MagmaGrp));
    res := New(SubgroupLat);
    res`Grp := G;
    res`outer_equivalence := false;
    res`inclusions_known := false;
    res`subs := [SubgroupLatElement(res, subs[i]`subgroup : i:=i, subgroup_count:=subs[i]`length) : i in [1..#subs]];
    //AddSpecialSubgroups(res); // just adds the labels since the subgroups already present
    res`index_bound := 0;
    return res;
end intrinsic;

function CollapseLatElement(L, subcls, i, lookup)
    A := subcls[1];
    x := SubgroupLatElement(L, A`subgroup : i:=i);
    x`cc_count := #subcls;
    x`subgroup_count := &+[Get(H, "subgroup_count") : H in subcls];
    x`normalizer := lookup[Get(A, "normalizer")];
    x`normal_closure := lookup[Get(A, "normal_closure")];
    if assigned A`characteristic_closure then
        x`characteristic_closure := lookup[A`characteristic_closure];
    end if;
    C := Get(A, "centralizer");
    x`centralizer := Type(C) eq NoneType select None() else lookup[C];
    if assigned A`gens then
        x`gens := A`gens;
    end if;
    if L`inclusions_known then
        // still using AssociativeArrays for compatibility with older code
        for ov -> b in Get(A, "overs") do
            x`overs[lookup[ov]] := b;
        end for;
        for un -> b in Get(A, "unders") do
            x`unders[lookup[un]] := b;
        end for;
        if assigned A`mobius_sub then
            x`mobius_sub := A`mobius_sub;
        end if;
        if assigned A`mobius_quo then
            x`mobius_quo := A`mobius_quo;
        end if;
    end if;
    return x;
end function;

intrinsic CollapseLatticeByAutGrp(L::SubgroupLat) -> SubgroupLat
{Takes a lattice of subgroups up to conjugacy and produces one up to automorphism}
    res := New(SubgroupLat);
    G := L`Grp;
    res`Grp := G;
    res`outer_equivalence := true;
    res`inclusions_known := L`inclusions_known;
    res`index_bound := L`index_bound;
    subs := Get(L, "by_index_aut");
    subs := &cat[subs[n] : n in Sort([k : k in Keys(subs)])];
    lookup, retract := Explode(Get(L, "aut_component_data"));
    // Have to make new SubgroupLatElements, since we're changing the lattice and modifying overs and unders
    res`subs := [CollapseLatElement(res, subs[i], i, lookup) : i in [1..#subs]];
    res`from_conj := <L, lookup>;
    return res;
end intrinsic;

intrinsic SubGrpLatAut(G::LMFDBGrp : edges:=true) -> SubgroupLat
{The lattice of subgroups up to automorphism}
    if Get(G, "HaveHolomorph") then
        return SubgroupLattice_edges(G, true);
    else
        return CollapseLatticeByAutGrp(Get(G, "SubGrpLat"));
    end if;
end intrinsic;

intrinsic SubGrpLat(G::LMFDBGrp : edges:=true) -> SubgroupLat
{The lattice of subgroups up to conjugacy}
    return SubgroupLattice_edges(G, false);
end intrinsic;

/* Even when we don't compute the lattice of inclusions it's sometimes necessary to find inclusion relations (to break ties among Gassman equivalent subgroups for example) */

intrinsic unders(x::SubgroupLatElt) -> Assoc
{}
    Lat := x`Lat;
    GG := Lat`Grp;
    G := GG`MagmaGrp;
    H := x`subgroup;
    aut := Lat`outer_equivalence and Get(GG, "HaveHolomorph");
    // It's alright to have duplication below, so we set aut to false since otherwise maximal_subgroup_classes would compute the Holomorph
    ans := AssociativeArray();
    for M in maximal_subgroup_classes(GG, H, aut : collapse:=false) do
        // We don't record the weights since that's not needed for this application.  We still use an associative array so that the data type of overs and unders doesn't change.
        i := SubgroupIdentify(Lat, M`subgroup);
        ans[i] := true;
    end for;
    return ans;
end intrinsic;

intrinsic overs(x::SubgroupLatElt) -> Assoc
{}
    // We build a list of candidate supergroups using Gassman vectors, then compute their "unders" and check if this is contained therein.
    Lat := x`Lat;
    GG := Lat`Grp;
    n := Get(GG, "order");
    m := x`order;
    ans := AssociativeArray();
    xvec := Get(x, "gassman_vec");
    by_index := Get(Lat, "by_index");
    for p in PrimeDivisors(n div m) do
        if IsDefined(by_index, n div (m*p)) then
            for h in by_index[n div (m*p)] do
                hvec := Get(h, "gassman_vec");
                if gvec_le(xvec, hvec) then
                    unders := Get(h, "unders");
                    if IsDefined(unders, x`i) then
                        ans[h`i] := true;
                    end if;
                end if;
            end for;
        end if;
    end for;
    return ans;
end intrinsic;

intrinsic aut_overs(x::SubgroupLatElt) -> Assoc
{One entry from each autjugacy class}
    Lat := x`Lat;
    overs := Get(x, "overs");
    if Lat`outer_equivalence then
        return overs;
    end if;
    aclass := Get(Lat, "aut_class");
    ans := AssociativeArray();
    for s in Keys(overs) do
        ans[aclass[s]] := true;
    end for;
    return ans;
end intrinsic;

intrinsic subgroup_count(x::SubgroupLatElt) -> RngIntElt
{}
    Lat := x`Lat;
    if assigned Lat`from_conj then
        conjL, lookup := Explode(Lat`from_conj);
        orbit := [i : i -> j in lookup | j eq lookup[x`i]];
        return &+[Get(conjL`subs[i], "subgroup_count") : i in orbit];
    elif Lat`outer_equivalence then
        Ambient := Get(Lat`Grp, "Holomorph");
        inj := Get(Lat`Grp, "HolInj");
    else
        Ambient := Lat`Grp`MagmaGrp;
        inj := IdentityHomomorphism(Ambient);
    end if;
    return Index(Ambient, Normalizer(Ambient, inj(x`subgroup)));
end intrinsic;

intrinsic cc_count(x::SubgroupLatElt) -> RngIntElt
{}
    Lat := x`Lat;
    if Lat`outer_equivalence then
        G := Lat`Grp`MagmaGrp;
        return Get(x, "subgroup_count") div Index(G, Normalizer(G, x`subgroup));
    else
        return 1;
    end if;
end intrinsic;

/*
// These functions were used when testing SubgroupLattice_edges
intrinsic AddConjugators(L::SubgroupLat)
{}
    G := L`Grp;
    GG := G`MagmaGrp;
    n := #GG;
    by_index := Get(L, "by_index");
    D := Sort([k : k in Keys(by_index) | k gt 1]);
    if G`outer_equivalence then
        Ambient := Get(G, "Holomorph");
        inj := Get(G, "HolInj");
    else
        Ambient := GG;
        inj := IdentityHomomorphism(GG);
    end if;
    L`conjugator := AssociativeArray();
    for d in D do
        M := [m : m in D | m ne d and IsDivisibleBy(m, d) and m ne n];
        for sub in by_index[d] do
            subvec := Get(sub, "gassman_vec");
            for m in M do
                for super in by_index[m] do
                    supervec := Get(super, "gassman_vec");
                    if gvec_le(subvec, supervec) then
                        conj, elt := IsConjugateSubgroup(Ambient, inj(super`subgroup), inj(sub`subgroup));
                        if conj then
                            L`conjugator[[sub`i, super`i]] := elt;
                        end if;
                    end if;
                end for;
            end for;
        end for;
    end for;
end intrinsic;

intrinsic ConjugatorTiming(N, i : aut:=true)
{}
    G := MakeSmallGroup(N, i : represent:=false, set_params:=false);
    G`outer_equivalence := aut;
    G`all_subgroups_known := true;
    G`subgroup_index_bound := 0;
    t0 := Cputime();
    if aut then
        L := Get(G, "SubGrpLstAut");
    else
        L := Get(G, "SubGrpLst");
    end if;
    print "List computed", Cputime() - t0;
    t0 := Cputime();
    for sub in L`subs do
        gv := Get(sub, "gassman_vec");
    end for;
    print "Gassman complete", Cputime() - t0;
    t0 := Cputime();
    AddConjugators(L);
    print "Conjugators complete", Cputime() - t0;
    G := MakeSmallGroup(N, i : represent:=false, set_params:=false);
    G`outer_equivalence := aut;
    G`all_subgroups_known := true;
    G`subgroup_index_bound := 0;
    t0 := Cputime();
    if aut then
        L := Get(G, "SubGrpLatAut");
    else
        L := Get(G, "SubGrpLat");
    end if;
    print "Lattice computed", Cputime() - t0;
end intrinsic;

intrinsic test_overs_unders(N, i : aut:=true) -> LMFDBGrp
{}
    G := MakeSmallGroup(N, i : represent:=false, set_params:=false);
    if aut then
        L1 := SubGrpLatAut(G);
    else
        L1 := SubGrpLat(G);
    end if;
    // We want the numbering of groups to be the same, so we just copy C1 and delete overs and unders
    L2 := New(SubgroupLat);
    L2`Grp := L1`Grp;
    L2`outer_equivalence := L1`outer_equivalence;
    L2`inclusions_known := false;
    subs := [];
    for x in L1`subs do
        Append(~subs, SubgroupLatElement(L2, x`subgroup : i:=x`i));
    end for;
    L2`subs := subs;
    shown := false;
    for j in [1..#subs] do
        if Keys(L1`subs[j]`overs) ne Keys(Get(L2`subs[j], "overs")) then
            if not shown then
                shown := true;
                print L1;
            end if;
            print j, "overs", Keys(L1`subs[j]`overs), Keys(Get(L2`subs[j], "overs"));
        end if;
        if Keys(L1`subs[j]`unders) ne Keys(Get(L2`subs[j], "unders")) then
            if not shown then
                shown := true;
                print L1;
            end if;
            print j, "unders", Keys(L1`subs[j]`unders), Keys(Get(L2`subs[j], "unders"));
        end if;
    end for;
    return G;
end intrinsic;
*/

intrinsic normal_closure(H::SubgroupLatElt) -> RngIntElt
{}
    // There's a faster version of this available when we have the subgroup inclusion diagram: just trace up through the subgroups containing this one with breadth-first search until a normal one is found.
    return SubgroupIdentify(H`Lat, NormalClosure(H`Lat`Grp`MagmaGrp, H`subgroup));
end intrinsic;

intrinsic normalizer(H::SubgroupLatElt) -> RngIntElt
{}
    return SubgroupIdentify(H`Lat, Normalizer(H`Lat`Grp`MagmaGrp, H`subgroup));
end intrinsic;

intrinsic centralizer(H::SubgroupLatElt) -> Any
{}
    conj, i, elt := SubgroupIdentify(H`Lat, Centralizer(H`Lat`Grp`MagmaGrp, H`subgroup) : get_conjugator:=true);
    return (conj select i else None());
end intrinsic;

intrinsic sort_pick(H::SubgroupLatElt) -> Grp
{A canonical conjugate of H.  Also sets H`sort_conj, which conjugates H`subgroup to H`sort_pick.}
    G := H`Lat`Grp;
    GG := G`MagmaGrp;
    if H`subgroup_count eq 1 then
        H`sort_conj := Identity(GG);
        return H`subgroup;
    end if;
    gens := Get(H, "sort_gens"); // sets sort_conj
    return sub<GG|gens>;
end intrinsic;

intrinsic aut_sort_pick(H::SubgroupLatElt) -> Grp
{A canonical autjugate of H.  Also sets H`aut_sort_conj, which conjugates H`subgroup to H`sort_pick.  Note that H`aut_sort_conj will be in the Holomorph}
    L := H`Lat;
    G := L`Grp;
    GG := G`MagmaGrp;
    if H`characteristic_closure eq H`i then
        if Get(G, "HaveHolomorph") then
            H`aut_sort_conj := Identity(Get(G, "Holomorph"));
        else
            H`aut_sort_conj := Identity(Get(G, "MagmaAutGroup"));
        end if;
        return H`subgroup;
    end if;
    gens := Get(H, "aut_sort_gens"); // sets aut_sort_conj
    return sub<GG|gens>;
end intrinsic;

function sortable(H)
    if Type(H) eq GrpPCElt then
        return Eltseq(H);
    elif Type(H) eq GrpPermElt then
        return cyc(H);
    elif Type(H) eq GrpMatElt then
        return H;
    else
        error Sprintf("Type %o not implemented", Type(H));
    end if;
end function;

function comp_sort_gens(H, aut)
    L := H`Lat;
    G0 := L`Grp;
    use_hol := Get(G0, "HaveHolomorph");
    // among overs, we first prioritize the path to the normal closure (since getting there stops the recursion), then we prioritize small index (inside the over, so maximal index of the over inside the ambient), then break ties by full_label
    if aut then
        if use_hol then
            Ambient := Get(G0, "Holomorph");
            inj := Get(G0, "HolInj");
        else
            Ambient := G0`MagmaGrp;
            inj := IdentityHomomorphism(Ambient);
        end if;
        cm := AutClassMap(G0);
        N := L`subs[Get(H, "characteristic_closure")];
        if N`i eq H`i then error "H must not be characteristic"; end if;
        D := {d : d in Divisors(N`order) | IsDivisibleBy(d, H`order) and d ne H`order};
        I := half_interval(N, "unders", D);
        orbit := [L`subs[i] : i in Get(L, "aut_orbit")[H`i]];
        poss := &cat[[<i, orb`i> : i in Keys(Get(orb, "overs")) | i in I] : orb in orbit];
        _, k := Min([<L`subs[i[1]]`order, L`subs[i[1]]`full_label, i[2]> : i in poss]);
        Hi := poss[k][2];
        Gi := poss[k][1];
        G := L`subs[Gi];
        GG := inj(Get(G, "aut_sort_pick"));
        HH := inj(L`subs[Hi]`subgroup);
        c := L`conjugator[[Hi, Gi]];
        if c cmpne true then // this would indicate that we're in the lattice of normal subgroups and thus don't need to conjugate
            if not L`outer_equivalence then
                c := inj(c);
            end if;
            HH := HH^c;
        end if;
        if use_hol then
            // we stored an element of the holomorph to conjugate by
            HH := HH^Get(G, "aut_sort_conj");
        else
            // we stored an automorphism
            f := Get(G, "aut_sort_conj");
            HH := f(HH);
        end if;
    else
        Ambient := G0`MagmaGrp;
        inj := IdentityHomomorphism(Ambient);
        cm := Get(G0, "ClassMap");
        N := L`subs[Get(H, "normal_closure")];
        if N`i eq H`i then error "H must not be normal"; end if;
        I := Interval(N, H : upward := Keys(Get(H, "overs")));
        by_index := Get(I, "by_index");
        poss := by_index[Max(Keys(by_index))];
        _, k := Min([x`full_label : x in poss]);
        G := poss[k];
        GG := Get(G, "sort_pick");
        HH := (H`subgroup)^(L`conjugator[[H`i, G`i]] * Get(G, "sort_conj"));
    end if;
    assert HH subset GG;
    // set gens
    M := #GG;
    C := ConjugacyClasses(HH); C := C[2..#C];
    X := IndexFibers([1..#C], func<i|cm(C[i][3] @@ inj)>);
    S := [k:k in Keys(X)];
    Z := [&+[M div #Centralizer(GG, C[j][3]): j in X[S[i]]] : i in [1..#S]];
    Ix := Sort([1..#S], func<a,b|Z[a] ne Z[b] select Z[a]-Z[b] else (S[a] lt S[b] select -1 else 1)>);
    S := [S[i]: i in Ix]; Z := [Z[i]: i in Ix];
    A := &cat[[h : h in Conjugates(GG, C[j][3])] : j in X[S[1]]];
    _, a := Min([sortable(h) : h in A]);
    a := A[a];
    gens := [a];
    K := sub<Ambient|gens>;
    T := Conjugates(GG, HH);
    n := 1;
    while #K lt #HH do
        if #T gt 1 then
            T := [t : t in T | K subset t];
            if #T eq 1 then
                _, g := IsConjugate(GG, HH, T[1]);
                HH := HH^g;
                C := [<c[1], c[2], c[3]^g> : c in C];
            end if;
        end if;
        for i in [n..#S] do
            if #T eq 1 then
                A := &cat[[h : h in C[j][3]^HH | not h in K]: j in X[S[i]]];
            else
                A := &cat[[h : h in C[j][3]^GG | not h in K and &or[h in t:t in T]] : j in X[S[i]]];
            end if;
            if #A eq 0 then continue; end if;
            n := i;
            _, a := Min([sortable(h) : h in A]);
            a := A[a];
            Append(~gens, a); K := sub<Ambient|gens>;
            break;
        end for;
    end while;
    if aut and not use_hol then
        b, conj := IsAutjugateSubgroup(L, H`subgroup, K); assert b;
    else
        b, conj := IsConjugate(Ambient, inj(H`subgroup), K); assert b;
    end if;
    if aut then
        H`aut_sort_conj := conj;
    else
        H`sort_conj := conj;
    end if;
    return [g @@ inj : g in gens];
end function;

intrinsic sort_gens(H::SubgroupLatElt) -> SeqEnum
{A canonical choice of generators of some conjugate.  H should not be normal}
    return comp_sort_gens(H, false);
end intrinsic;

intrinsic aut_sort_gens(H::SubgroupLatElt) -> SeqEnum
{A canonical choice of generators of some autjugate.  H should not be characteristic}
    return comp_sort_gens(H, true);
end intrinsic;

intrinsic sort_key(H::SubgroupLatElt, aut::BoolElt) -> Any
{A sortable object canonically defined by this conjugacy class}
    if aut then
        return [sortable(g) : g in Get(H, "aut_sort_gens")];
    else
        return [sortable(g) : g in Get(H, "sort_gens")];
    end if;
end intrinsic;

/* turns G`label and output of LabelSubgroups into string */

function CreateLabel(Glabel, Hlabel)
    if #Hlabel gt 0 then
        return Glabel * "." * Join([Sprint(x) : x in Hlabel], ".");
    else // used for special subgroups where there is only a suffix
        return Glabel;
    end if;
end function;

intrinsic LMFDBSubgroup(H::SubgroupLatElt : normal_lattice:=false) -> LMFDBSubGrp
{}
    Lat := H`Lat;
    G := Lat`Grp;
    res := New(LMFDBSubGrp);
    res`Grp := G;
    res`MagmaAmbient := G`MagmaGrp;
    res`MagmaSubGrp := H`subgroup;
    res`standard_generators := H`standard_generators;
    res`label := G`label * "." * H`label;
    res`short_label := H`label;
    if assigned H`aut_label then
        res`aut_label := Sprintf("%o.%o%o", H`aut_label[1], CremonaCode(H`aut_label[2]), H`aut_label[3]);
    end if;
    res`special_labels := H`special_labels;
    res`count := Get(H, "subgroup_count");
    res`conjugacy_class_count := Get(H, "cc_count");
    res`characteristic := Get(H, "characteristic");
    if Lat`inclusions_known then
        res`contains := [Lat`subs[k]`label : k in Keys(H`unders)]; // Sort
        res`contained_in := [Lat`subs[k]`label : k in Keys(H`overs)]; // Sort
        res`mobius_sub := (assigned H`mobius_sub) select H`mobius_sub else None();
        res`mobius_quo := (assigned H`mobius_quo) select H`mobius_quo else None();
    // port mobius_quo from normal subgroups
    else
        res`contains := None();
        res`contained_in := None();
        res`mobius_sub := None();
        res`mobius_quo := None();
    end if;
    if not normal_lattice then
        N := Get(H, "normalizer");
        res`normalizer := Lat`subs[N]`label;
        res`normalizer_index := Get(G, "order") div Lat`subs[N]`order;
        res`normal_closure := Lat`subs[Get(H, "normal_closure")]`label;
        C := Get(H, "centralizer");
        res`centralizer := (Type(C) eq NoneType) select None() else Lat`subs[C]`label;
        res`centralizer_order := (Type(C) eq NoneType) select None() else Lat`subs[C]`order;
    end if;
    AssignBasicAttributes(res);
    return res;
end intrinsic;

intrinsic BestSubgroupLat(G::LMFDBGrp) -> SubgroupLat
{}
    if G`outer_equivalence then
        if G`subgroup_inclusions_known then
            return Get(G, "SubGrpLatAut");
        else
            return Get(G, "SubGrpLstAut");
        end if;
    else
        if G`subgroup_inclusions_known then
            return Get(G, "SubGrpLat");
        else
            return Get(G, "SubGrpLst");
        end if;
    end if;
end intrinsic;

intrinsic Subgroups(G::LMFDBGrp) -> SeqEnum
    {The list of LMFDBSubGrps computed for this group}
    L := BestSubgroupLat(G);
    vprint User1: "Labeling subgroups";
    LabelSubgroups(L);
    vprint User1: "Subgroups labelled";
    return [LMFDBSubgroup(H) : H in L`subs];
    /*if G`all_subgroups_known and not G`outer_equivalence then // Remove G`outer_equivalence once Magma bugs around automorphisms are fixed or worked around
        SaveSubgroupCache(G, S);
    end if;*/
end intrinsic;

procedure SetMobiusQuo(~L, aut)
    L`subs[#L]`mobius_quo := 1;
    for i in [#L-1..1 by -1] do
        x := L`subs[i];
        x`mobius_quo := 0;
        for j in half_interval(x, "unders", {}) do
            y := L`subs[j];
            if x`i ne y`i then
                // both are normal, so there is only 1 inclusion unless working up to automorphism
                n := aut select NumberOfInclusions(y, x) else 1;
                x`mobius_quo -:= n * y`mobius_quo;
            end if;
        end for;
    end for;
end procedure;

intrinsic NormSubGrpLat(G::LMFDBGrp) -> SubgroupLat
{Lattice of normal subgroups}
    L := New(SubgroupLat);
    L`Grp := G;
    GG := G`MagmaGrp;
    L`outer_equivalence := false;
    L`inclusions_known := true;
    L`index_bound := 0;
    subs := Reverse(NormalSubgroups(GG));
    L`subs := [SubgroupLatElement(L, subs[i]`subgroup : i:=i, normal:=true) : i in [1..#subs]];
    ComputeLatticeEdges(~L, GG, IdentityHomomorphism(GG) : normal_lattice:=true);
    SetClosures(~L);
    SetMobiusQuo(~L, false);
    return L;
end intrinsic;

// Need to set label, aut_label
intrinsic NormSubGrpLatAut(G::LMFDBGrp) -> SubgroupLat
{Lattice of normal subgroups up to automorphism}
    if Get(G, "solvable") and Get(G, "HaveHolomorph") then
        L := New(SubgroupLat);
        L`Grp := G;
        L`outer_equivalence := true;
        L`inclusions_known := true;
        L`index_bound := 0;
        subs := SolvAutSubs(G : normal:=true);
        L`subs := [SubgroupLatElement(L, subs[i]`subgroup : i:=i, normal:=true) : i in [1..#subs]];
        ComputeLatticeEdges(~L, Get(G, "Holomorph"), Get(G, "HolInj"));
        SetClosures(~L);
        SetMobiusQuo(~L, true);
        return L;
    else
        // This assumes more attributes are set than NormSubGrpLat currently does
        return CollapseLatticeByAutGrp(Get(G, "NormSubGrpLat"));
    end if;
end intrinsic;

intrinsic NormalSubgroups(G::LMFDBGrp) -> Any
{lattice of normal subgroups, or None if not computed}
    // semidirect_product: need to find complements for each (currently implemented as a LMFDBSubGrp)
    // central_product: need to get central_factor
    // direct product should probably depend on this
    // should ideally get recycled when filling in normal subgroups (especially since complements are saved)
    if Get(G, "outer_equivalence") then
        L := Get(G, "NormSubGrpLatAut");
    else
        L := Get(G, "NormSubGrpLat");
    end if;
    LabelNormalSubgroups(L); // TODO
    return [LMFDBSubgroup(H : normal_lattice:=true) : H in L`subs];
end intrinsic;

intrinsic LowIndexSubgroups(G::LMFDBGrp, d::RngIntElt) -> SeqEnum
    {List of low index LMFDBSubGrps, or None if not computed}
    m := G`subgroup_index_bound;
    if d eq 0 then
        if m eq 0 then
            return Get(G, "Subgroups");
        else
            return None();
        end if;
    end if;
    if m eq 0 or d le m then
        LIS := [];
        ordbd := Get(G, "order") div d;
        for H in Get(G, "Subgroups") do
            if Get(H, "subgroup_order") gt ordbd then
                Append(~LIS, H);
            end if;
        end for;
        return LIS;
    else;
        return None();
    end if;
end intrinsic;

intrinsic LookupSubgroupLabel(G::LMFDBGrp, HH::Any) -> Any
{Find a subgroup label for H, or return None if H is not labeled}
    if Type(HH) eq MonStgElt then
        // already labeled
        return HH;
    else
        L := BestSubgroupLat(G);
        try
            x := L`subs[SubgroupIdentify(L, HH)];
        catch e
            return "\\N";
        end try;
        return x`label;
    end if;
end intrinsic;

intrinsic LookupSubgroup(G::LMFDBGrp, label::MonStgElt) -> Grp
{Find a subgroup with a given label}
    S := Get(G, "Subgroups");
    for K in S do
        if label eq Get(K, "label") or label in Get(K, "special_labels") then
            return Get(K, "MagmaSubGrp");
        end if;
    end for;
    error Sprintf("Subgroup with label %o not found", label);
end intrinsic;


/*
The following code was part of an unsuccessful attempt to use the lattice to find all_minimal_chains.
It does not produce correct results and needs some additional idea to make functional.
It hasn't been deleted because it's faster than the current version of all_minimal_chains...
*/

intrinsic CyclicQuotients(top::SubgroupLatElt) -> SeqEnum
{}
    /* WARNING: This function can return incorrect results */
    Lat := top`Lat;
    H := top`subgroup;
    D := Lat!DerivedSubgroup(H);
    divs := {d : d in Divisors(top`order) | IsDivisibleBy(d, D`order)};
    down := half_interval(top, "unders", divs) meet half_interval(D, "overs", divs);
    poss := Sort([i : i in down | i ne top`i]);
    ans := [];
    while #poss gt 0 do
        i := poss[1];
        bottom := Lat`subs[i];
        if IsDefined(top`unders, i) then
            // maximal subgroup of top
            Append(~ans, bottom);
            Remove(~poss, 1);
            continue;
        end if;
        I := Interval(top, bottom : downward:=down);
        if IsProbablyCyclic(I) then
            Append(~ans, bottom);
            Remove(~poss, 1);
        else
            pruned := half_interval(bottom, "unders", divs);
            for i in pruned do
                // Faster to sort and do one pass, but unlikely to be dominant step
                Exclude(~poss, i);
            end for;
        end if;
    end while;
    return ans;
end intrinsic;

intrinsic IsProbablyCyclic(I::SubgroupLatInterval) -> BoolElt
{Whether the quotient top/bottom is cyclic.
Assumes that the quotient of the top by every intermediate node is (probably) cyclic,
and that that the bottom node contains the derived subgroup of the top.

This can fail and produce spurious results:
G := MakeSmallGroup(256, 34);
Lat := Get(G, "SubGrpLatAut");
IsProbablyCyclic(Interval(Lat!5, Lat!26));
true
IsActuallyCyclic(Interval(Lat!5, Lat!26));
false
}
    /* WARNING: This function can return incorrect results */
    if Empty(I) then return false; end if;
    n := Get(I`Lat`Grp, "order");
    D := Sort([n div d : d in Divisors(I`top`order) | IsDivisibleBy(d, I`bottom`order)]);
    by_index := Get(I, "by_index");
    for d in D do
        if not IsDefined(by_index, d) or #by_index[d] ne 1 then
            return false;
        end if;
    end for;
    // There's maybe a faster way to do this but this is simple
    bcnt := I`bottom`subgroup_count;
    for d1 in D do
        outer_prod := bcnt * by_index[d1][1]`subgroup_count;
        for d2 in D do
            if IsDivisibleBy(d2, d1) and not IsDivisibleBy(outer_prod, by_index[d2][1]`subgroup_count) then
                return false;
            end if;
        end for;
    end for;

    // I couldn't get the following reasoning to work....
    // Let NT be the normalizer of the top, and NH be the normalizer of some subgroup H in the interval
    // top is normal in NT, so if we work inside NT we need that there is only one NT-conjugacy class of subgroup conjugate to H (that contains bottom), ie H is normal inside NT or that NH contains NT. 
    return true;
end intrinsic;

intrinsic IsActuallyCyclic(I::SubgroupLatInterval) -> BoolElt
{}
    top := I`top`subgroup;
    bottom := I`bottom`subgroup;
    if bottom subset top then
        return IsNormal(top, bottom) and IsCyclic(quo<top | bottom>);
    else
        N := Normalizer(I`Lat`Grp`MagmaGrp, bottom);
        T := Transversal(I`Lat`Grp`MagmaGrp, N);
        for t in T do
            Bt := bottom^t;
            if Bt subset top then
                return IsNormal(top, Bt) and IsCyclic(quo<top | Bt>);
            end if;
        end for;
    end if;
    error "no inclusion found";
end intrinsic;

intrinsic all_minimal_chains_lat(G::LMFDBGrp) -> SeqEnum
{Aimed to return all minimal length chains of subgroups so that each is normal in the previous with cyclic quotient.
 Unfortunately, because the lattice is up to conjugacy it's difficult to predict when a quotient is cyclic just from containment information.  Here's an example:
G := SmallGroup(256, 33);
gens := PCGenerators(G);
H := sub<G|gens[1], gens[3], gens[7]*gens[8]>;
K1 := sub<G|gens[3], gens[4]>;
K2 := sub<G|gens[3] * gens[4] * gens[6] * gens[8], gens[4] * gens[7] * gens[8]>;
K1 subset H and IsNormal(H, K1);
true
K2 subset H and IsNormal(H, K2);
true
Hol, inj := Holomorph(G);
conj, elt := IsConjugate(Hol, inj(K1), inj(K2));
conj;
true
IsCyclic(H/K1);
false
IsCyclic(H/K2);
true
K1 and K2 are in the same class, but their quotients are different (the automorphism that maps K1 to K2 doesn't fix H).
}
    /* WARNING: This function can return incorrect results */
    assert Get(G, "solvable");
    //L := G`outer_equivalence select Get(G, "SubGrpLatAut") else Get(G, "SubGrpLat");
    L := Get(G, "SubGrpLatAut");
    cycdist := AssociativeArray();
    top := L!1; // backward from how Magma internal lattices number
    bottom := L!(#L);
    cycdist[top] := 0;
    reverse_path := AssociativeArray();
    Seen := {top};
    Layer := {top};
    while true do
        NewLayer := {};
        for h in Layer do
            for x in CyclicQuotients(h) do
                if not IsDefined(cycdist, x) or cycdist[x] gt cycdist[h] + 1 then
                    cycdist[x] := cycdist[h] + 1;
                    reverse_path[x] := {h};
                elif cycdist[x] eq cycdist[h] + 1 then
                    Include(~(reverse_path[x]), h);
                end if;
                if not (x in Seen) then
                    Include(~NewLayer, x);
                    Include(~Seen, x);
                end if;
            end for;
        end for;
        Layer := NewLayer;
        if (bottom in Layer) then
            break;
        elif (#Layer eq 0) then
            error "Didn't reach bottom";
        end if;
    end while;
    M := cycdist[bottom];
    chains := [[bottom]];
    for i in [1..M] do
        new_chains := [];
        for chain in chains do
            for x in reverse_path[chain[i]] do
                Append(~new_chains, Append(chain, x));
            end for;
        end for;
        chains := new_chains;
    end for;
    return chains;
end intrinsic;


intrinsic AMCCompare(N, i) -> LMFDBGrp, SubgroupLat
{Compares results of the two all_minimal_chains algorithms in the pursuit of finding bugs}
    G := MakeSmallGroup(N, i : set_params:=false);
    t0 := Cputime();
    Lat := Get(G, "SubGrpLatAut");
    print "Lattice", Cputime() - t0;
    t0 := Cputime();
    chains1 := all_minimal_chains_lat(G);
    print "Lattice chains", Cputime() - t0;
    t0 := Cputime();
    chains2 := all_minimal_chains(G);
    print "Derived chains", Cputime() - t0;
    S1 := {[c`i : c in chain] : chain in chains1};
    S2 := {[(Lat!(c`subgroup))`i : c in chain] : chain in chains2};
    missing := S1 diff S2;
    if #missing gt 0 then
        print "Missing", #missing;
        for latchain in missing do
            print Join([Sprint(c) : c in latchain], " ");
        end for;
    end if;
    extra := S2 diff S1;
    if #extra gt 0 then
        print "Extra", #extra;
        for latchain in extra do
            print Join([Sprint(c) : c in latchain], " ");
        end for;
    end if;
    return G, Lat;
end intrinsic;

