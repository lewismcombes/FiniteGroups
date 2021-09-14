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
end intrinsic;

RF := recformat<subgroup, order, length>;
declare type SubgroupLatElt;
declare attributes SubgroupLatElt:
        Lat,
        subgroup,
        order,
        gens,
        i, // can be negative during construction, but set to the index in subs when complete
        aut_label, // list of integers giving the automorphism part of the label
        full_label, // list of integers giving the full label
        label, // string giving the label (omitting the N.i from the group label)
        special_labels, // other labels (normal, maximal, special; omitting the N.i)
        unders, // other subs this sub contains maximally, as an associative array i->cnt, where i is the index in subs and cnt is the number of reps in that class contained in a single rep of this class
        overs, // other subs this sub is contained in minimally, in the same format
        mobius, // value of the mobius function on this node of the lattice
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
        normal_closure;

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
        index_bound;

declare type SubgroupLatInterval;
declare attributes SubgroupLatInterval:
        Lat,
        top,
        bottom,
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

function SplitByAuts(L, H, inj : use_order:=true, use_hash:=true, use_gassman:=false)
    // L is a list of lists of records or SubgroupLatElts, including `order and `subgroup
    // Gassman class is slow in holomorphs
    function check_done(M)
        return &and[#x eq 1 : x in M];
    end function;
    function get_easy_hash(x)
        if Type(x) eq Rec then return EasyHash(x`subgroup); end if;
        return Get(x, "easy_hash");
    end function;
    gvstr := (H cmpeq Codomain(inj)) select "gassman_vec" else "aut_gassman_vec";
    function get_gassman_vec(x)
        if Type(x) eq Rec then
            if gvstr eq "gassman_vec" then
                return SubgroupClass(x`subgroup, Get(L`Grp, "ClassMap"));
            else
                return SubgroupClass(x`subgroup, AutClassMap(L`Grp));
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
    for chunk in L do
        if #chunk gt 1 then
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
        else
            Append(~newL, chunk);
        end if;
    end for;
    return newL;
end function;

function bia(L)
    H := Get(L`Grp, "Holomorph");
    inj := Get(L`Grp, "HolInj");
    ans := AssociativeArray();
    for index -> subs in L`by_index do
        if L`outer_equivalence then
            ans[index] := [[s] : s in subs];
        else
            ans[index] := SplitByAuts([subs], H, inj);
        end if;
    end for;
    return ans;
end function;

intrinsic by_index_aut(L::SubgroupLat) -> Assoc
{}
    return bia(L);
end intrinsic;

intrinsic aut_class(L::SubgroupLat) -> Assoc
{}
    bia := Get(L, "by_index_aut");
    ans := AssociativeArray();
    for index -> aclasses in bia do
        for aclass in aclasses do
            first := Min([s`i : s in aclass]);
            for s in aclass do
                ans[s`i] := first;
            end for;
        end for;
    end for;
    return ans;
end intrinsic;

intrinsic Holomorph(X::LMFDBGrp) -> Grp
{}
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

intrinsic CCAutCollapse(X::LMFDBGrp) -> Map
{}
    Hol := Get(X, "Holomorph");
    inj := Get(X, "HolInj");
    CC := ConjugacyClasses(X);
    D := Classify([1..#CC], func<i, j | IsConjugate(Hol, inj(CC[i]`representative), inj(CC[j]`representative))>);
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

function ByIndex(L, n)
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
end function;

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

intrinsic SubGrpLstAut(X::LMFDBGrp) -> SubgroupLat
    {The list of subgroups up to automorphism, cut off by an index bound if too many}
    G := X`MagmaGrp;
    N := Get(X, "order");
    Ambient := Get(X, "Holomorph");
    inj := Get(X, "HolInj");
    trim := true;
    ordbd := 1;
    if Get(X, "solvable") then
        // In the most common case, we can use SubgroupsLift inside the holomorph to get autjugacy classes
        subs := SolvAutSubs(X);
    else
        if AllSubgroupsOk(G) then
            // In this case, we compute all subgroups and then group them by autjugacy
            subs := Get(X, "SubGrpLst");
            subs := SplitByAuts([subs`subs], Ambient, inj);
            X`SubGrpAutOrbits := subs;
        else
            trim := false;
            // There may be too many subgroups, so we work by index
            D := Reverse(Divisors(N));
            subs := [];
            extra_subs := [];
            count := 0;
            for d in D do
                dsubs := Subgroups(G : OrderEqual := d);
                dsubs := SplitByAuts([dsubs], Ambient, inj : use_order := false);
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
                    X`number_characteristic_subgroups := #[H : H in Norms | IsNormal(Ambient, inj(H))];
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
        subs := [x[1] : x in subs];
    end if;
    if ordbd eq 1 then
        X`number_subgroup_autclasses := #subs;
        nchar := 0;
        nnorm := 0;
        nsubs := 0;
        nconj := 0;
        for x in subs do
            acnt := Index(Ambient, Normalizer(Ambient, inj(x`subgroup)));
            if acnt eq 1 then nchar +:= 1; end if;
            nsubs +:= acnt;
            ccnt := Index(G, Normalizer(G, x`subgroup));
            if ccnt eq 1 then nnorm +:= 1; end if;
            nconj +:= acnt div ccnt;
        end for;
        X`number_characteristic_subgroups := nchar;
        X`number_normal_subgroups := nnorm;
        X`number_subgroups := nsubs;
        X`number_subgroup_classes := nconj;
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
    res`by_index := ByIndex(res`subs, #G);
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

intrinsic SubgroupLatElement(L::SubgroupLat, H::Grp : i:=false, normalizer:=false, centralizer:=false, normal_closure:=false, gens:=false, subgroup_count:=false, standard:=false, recurse:=0) -> SubgroupLatElt
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
//Requires by_index to be set, but not subgroup_count, overs or unders on the elements
//If get_conjugator is true, returns three things: is_conj, i, conjugating element
//Otherwise, just returns i and raises an error if not found
    G := L`Grp`MagmaGrp;
    ind := #G div #H;
    if not IsDefined(L`by_index, ind) then
        if get_conjugator then
            return false, 0, Identity(G);
        else
            error "Subgroup not found";
        end if;
    end if;
    poss := L`by_index[#G div #H];
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
    for d in Sort([k : k in Keys(Lat`by_index)]) do
        m := n div d;
        for H in Lat`by_index[d] do
            Append(~lines, Sprintf("[%o]  Order %o  Length %o  Maximal Subgroups: %o", H`i, m, H`subgroup_count, Join([Sprint(u) : u in Sort([j : j in Keys(H`unders)])], " ")));
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
    return #I`by_index eq 0;
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
    I`by_index := AssociativeArray();
    seen := half_interval(x, dir, D);
    for i in seen do
        cur := Lat`subs[i];
        ind := n div cur`order;
        if IsDefined(I`by_index, ind) then
            Append(~I`by_index[ind], cur);
        else
            I`by_index[ind] := [cur];
        end if;
    end for;
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
    I`by_index := AssociativeArray();
    D := {d : d in Divisors(top`order) | IsDivisibleBy(d, bottom`order)};
    if #downward eq 0 then downward := half_interval(top, "unders", D); end if;
    if #upward eq 0 then upward := half_interval(bottom, "overs", D); end if;
    for i in downward meet upward do
        cur := Lat`subs[i];
        ind := n div cur`order;
        if IsDefined(I`by_index, ind) then
            Append(~I`by_index[ind], cur);
        else
            I`by_index[ind] := [cur];
        end if;
    end for;
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
function maximal_subgroup_classes(Ambient, H, inj : collapse:=true)
    // Ambient = G or Holomoprph(G)
    // H is a subgroup of G
    // inj is the map from G to Ambient
    // N is the normalizer of H inside Ambient
    // Returns a list of records giving maximal subgroups of H up to conjugacy in Ambient; if collapse then guaranteed to be inequivalent
    if IsTrivial(H) then return []; end if;
    function do_collapse(results)
        if collapse then
            results := SplitByAuts([results], Ambient, inj);
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
    Mlist := maximal_subgroup_classes(Ambient, G, inj : collapse:=true);
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
            cache := LoadSubgroupCache(lab);
            if Valid(cache) then // until the bugs in automorphism groups are worked around, we only save caches where outer_equivalence is false
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
            this_index := SplitByAuts(this_index, Ambient, inj : use_order:=false);
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
                for K in maximal_subgroup_classes(Ambient, H`subgroup, inj : collapse:=false) do
                    KK := SubgroupLatElement(Lat, K`subgroup : gens:=[G!g : g in Generators(G)], recurse:=true);
                    KK`overs[#collapsed] := K`length;
                    Append(~to_add[#G div K`order], KK);
                end for;
            end if;
        end for;
    end for;
    Lat`subs := collapsed;
    Lat`by_index := ByIndex(collapsed, #G);
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
    // Set the mobius function
    /*Lat`subs[1]`mobius := 1; //μ_G(G) = 1
    for i in [2..#Lat`subs] do
        x := Lat`subs[i];
        x`mobius := 0;
        for j in half_interval(x, "overs", {}) do
            y := Lat`subs[j];
            x`mobius -:= (y`subgroup_count * NumberOfInclusions(x, y) * y`mobius) div x`subgroup_count;
        end for;
    end for;*/
    AddSpecialSubgroups(Lat); // just adds the labels since the subgroups already present
    return Lat;
end function;

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
    one := Identity(Ambient);
    n := #GG;
    C := AssociativeArray();
    overs := [{Integers()|} : i in [1..#L]];
    unders := [{Integers()|} : i in [1..#L]];
    // We start by adding all edges with prime order
    D := Reverse(Sort([k : k in Keys(L`by_index)]));
    vprint User1: "Adding length 1 edges";
    //print "D", D;
    for d in D do
        M := [m : m in D | IsDivisibleBy(d, m) and IsPrime(d div m)];
        for sub in L`by_index[d] do
            //print d, sub`order;
            subvec := Get(sub, "gassman_vec");
            //print "subvec", sprint(subvec);
            for m in M do
                for super in L`by_index[m] do
                    supervec := Get(super, "gassman_vec");
                    //print "supervec", sprint(supervec);
                    //print "orders", sub`order, super`order;
                    if gvec_le(subvec, supervec) then
                        conj, elt := IsConjugateSubgroup(Ambient, inj(super`subgroup), inj(sub`subgroup));
                        if conj then
                            C[[sub`i, super`i]] := elt;
                            //print "HERE", sub`i, #overs;
                            Include(~overs[sub`i], super`i);
                            Include(~unders[super`i], sub`i);
                            //print "Including", sub`i, super`i;
                        end if;
                    end if;
                end for;
            end for;
        end for;
    end for;
    vprint User1: "Length 1 edges added";

    procedure propogate_edges(~CC, bottom, new_edges)
        // Recursively propogate the addition of some edges to fill in all relevant new comparisons in C
        // new_edges should be a list of integers, each the top of a new edge from bottom
        current := &cat[[<ov, i> : i in overs[ov]] : ov in new_edges];
        while #current gt 0 do
            next := [];
            for pair in current do
                top := pair[2];
                if IsDefined(CC, [bottom, top]) then continue; end if;
                mid := pair[1];
                if CC[[bottom, mid]] eq one and CC[[mid, top]] eq one then
                    CC[[bottom, top]] := one;
                elif L`subs[bottom]`subgroup subset L`subs[top]`subgroup then
                    // We want use use one whenever possible
                    CC[[bottom, top]] := one;
                else
                    CC[[bottom, top]] := CC[[bottom, mid]] * CC[[mid, top]];
                end if;
                next cat:= [<top, i> : i in overs[top]];
            end for;
            current := next;
        end while;
    end procedure;

    // Now create longer edges
    for bottom in [1..#L] do
        propogate_edges(~C, bottom, overs[bottom]);
    end for;

    // Now we need to add edges coming from inclusions that are not of prime order
    for d in D do
        M := [m : m in D | m ne d and IsDivisibleBy(d, m) and not IsPrime(d div m)];
        for sub in L`by_index[d] do
            subvec := Get(sub, "gassman_vec");
            for m in M do
                for super in L`by_index[m] do
                    supervec := Get(super, "gassman_vec");
                    if IsDefined(C, [sub`i, super`i]) then continue; end if;
                    if gvec_le(subvec, supervec) then
                        conj, elt := IsConjugateSubgroup(Ambient, inj(super`subgroup), inj(sub`subgroup));
                        if conj then
                            C[[sub`i, super`i]] := elt;
                            Include(~overs[sub`i], super`i);
                            Include(~unders[super`i], sub`i);
                            // We need to propogate this new edge up to the top of the lattice
                            propogate_edges(~C, sub`i, [super`i]);
                        end if;
                    end if;
                end for;
            end for;
        end for;
    end for;
    vprint User1: "Longer edges added";
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

    // Set the mobius function
    L`subs[1]`mobius := 1; //μ_G(G) = 1
    for i in [2..#L] do
        x := L`subs[i];
        x`mobius := 0;
        //print "x", x`i;
        for j in half_interval(x, "overs", {}) do
            y := L`subs[j];
            if x`i eq y`i then continue; end if;
            //print x`i, y`i, Get(y, "subgroup_count"), NumberOfInclusions(x, y), y`mobius, Get(x, "subgroup_count");
            x`mobius -:= (Get(y, "subgroup_count") * NumberOfInclusions(x, y) * y`mobius) div Get(x, "subgroup_count");
        end for;
        //print "mobius", x`mobius;
    end for;
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
    res`by_index := ByIndex(res`subs, Get(G, "order"));
    AddSpecialSubgroups(res); // just adds the labels since the subgroups already present
    res`index_bound := 0;
    return res;
end intrinsic;

intrinsic SubGrpLatAut(G::LMFDBGrp : edges:=true) -> SubgroupLat
{The lattice of subgroups up to automorphism}
    if edges then
        return SubgroupLattice_edges(G, true);
    end if;
    return SubgroupLattice(G, true);
end intrinsic;

intrinsic SubGrpLat(G::LMFDBGrp : edges:=true) -> SubgroupLat
{The lattice of subgroups up to conjugacy}
    if edges then
        return SubgroupLattice_edges(G, false);
    end if;
    return SubgroupLattice(G, false);
end intrinsic;

/* Even when we don't compute the lattice of inclusions it's sometimes necessary to find inclusion relations (to break ties among Gassman equivalent subgroups for example) */

intrinsic unders(x::SubgroupLatElt) -> Assoc
{}
    Lat := x`Lat;
    GG := Lat`Grp;
    G := GG`MagmaGrp;
    H := x`subgroup;
    if Lat`outer_equivalence then
        Ambient := Get(GG, "Holomorph");
        inj := Get(GG, "HolInj");
    else
        Ambient := G;
        inj := IdentityHomomorphism(G);
    end if;
    ans := AssociativeArray();
    for M in maximal_subgroup_classes(Ambient, H, inj : collapse:=false) do
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
    for p in PrimeDivisors(n div m) do
        for h in Lat`by_index[n div (m*p)] do
            hvec := Get(h, "gassman_vec");
            if gvec_le(xvec, hvec) then
                unders := Get(h, "unders");
                if IsDefined(unders, x`i) then
                    ans[h`i] := true;
                end if;
            end if;
        end for;
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
    if Lat`outer_equivalence then
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
    D := Sort([k : k in Keys(L`by_index) | k gt 1]);
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
        for sub in L`by_index[d] do
            subvec := Get(sub, "gassman_vec");
            for m in M do
                for super in L`by_index[m] do
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
    L2`by_index := ByIndex(subs, Get(G, "order"));
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

/* turns G`label and output of LabelSubgroups into string */

function CreateLabel(Glabel, Hlabel)
    if #Hlabel gt 0 then
        return Glabel * "." * Join([Sprint(x) : x in Hlabel], ".");
    else // used for special subgroups where there is only a suffix
        return Glabel;
    end if;
end function;

intrinsic LMFDBSubgroup(H::SubgroupLatElt) -> LMFDBSubGrp
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
    res`aut_label := Sprintf("%o.%o%o", H`aut_label[1], CremonaCode(H`aut_label[2]), H`aut_label[3]);
    res`special_labels := H`special_labels;
    res`count := Get(H, "subgroup_count");
    res`conjugacy_class_count := Get(H, "cc_count");
    if Lat`inclusions_known then
        res`contains := [Lat`subs[k]`label : k in Keys(H`unders)]; // Sort
        res`contained_in := [Lat`subs[k]`label : k in Keys(H`overs)]; // Sort
        res`mobius_function := H`mobius;
    else
        res`contains := None();
        res`contained_in := None();
        res`mobius_function := None();
    end if;
    res`normalizer := Lat`subs[Get(H, "normalizer")]`label;
    res`normal_closure := Lat`subs[Get(H, "normal_closure")]`label;
    C := Get(H, "centralizer");
    res`centralizer := (Type(C) eq NoneType) select None() else Lat`subs[C]`label;
    AssignBasicAttributes(res);
    return res;
end intrinsic;

intrinsic Subgroups(G::LMFDBGrp) -> SeqEnum
    {The list of LMFDBSubGrps computed for this group}
    t0 := Cputime();
    S := [];
    GG := G`MagmaGrp;
    if G`outer_equivalence then
        if G`subgroup_inclusions_known then
            L := Get(G, "SubGrpLatAut");
        else
            L := Get(G, "SubGrpLstAut");
        end if;
    else
        if G`subgroup_inclusions_known then
            L := Get(G, "SubGrpLat");
        else
            L := Get(G, "SubGrpLst");
        end if;
    end if;
    LabelSubgroups(L);
    S := [LMFDBSubgroup(H) : H in L`subs];
    /*if G`all_subgroups_known and not G`outer_equivalence then // Remove G`outer_equivalence once Magma bugs around automorphisms are fixed or worked around
        SaveSubgroupCache(G, S);
    end if;*/
    return S;
end intrinsic;

intrinsic NormalSubgroups(G::LMFDBGrp) -> Any
    {List of normal LMFDBSubGrps, or None if not computed}
    if not G`normal_subgroups_known then
        return None();
    end if;
    return [H : H in Get(G, "Subgroups") | H`normal];
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
        S := Get(G, "Subgroups");
        GG := Get(G, "MagmaGrp");
        for K in S do
            KK := Get(K, "MagmaSubGrp");
            if IsConjugate(GG, HH, KK) then
                v := Get(K, "label");
                if Type(v) eq NoneType then
                    v := Get(K, "special_label")[1];
                end if;
                return v;
            end if;
        end for;
        return "\\N";
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
    for d in D do
        if not IsDefined(I`by_index, d) or #I`by_index[d] ne 1 then
            return false;
        end if;
    end for;
    // There's maybe a faster way to do this but this is simple
    bcnt := I`bottom`subgroup_count;
    for d1 in D do
        outer_prod := bcnt * I`by_index[d1][1]`subgroup_count;
        for d2 in D do
            if IsDivisibleBy(d2, d1) and not IsDivisibleBy(outer_prod, I`by_index[d2][1]`subgroup_count) then
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

