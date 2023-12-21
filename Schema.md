# Groups

## Abstract groups

`gps_groups`: Abstract groups up to isomorphism

Column            | Type     | Notes
------------------|----------|------
label             | text     | GAP ID encoded as a string `N.i`, where `N` is the order of the group and `i` distinguishes groups of the same order (as determined in GAP).  If not in the Small groups database, replace `i` with an incrementing Cremona letter code.
old_label         | text     | If the label has been switched from temp to permanent, store temp here.
name              | text     | Primary description
tex_name          | text     | Latex version of the primary description
order             | numeric  | Size of the group
counter           | integer  | The value of `i`
factors_of_order  | smallint[] | List of primes dividing the order
exponent          | integer  | Exponent of the group
abelian           | boolean  |
cyclic            | boolean  |
solvable          | boolean  | chain of normal subgroups with abelian quotients
supersolvable     | boolean  | chain of normal subgroups with cyclic quotients
nilpotent         | boolean  |
metacyclic        | boolean  | extension of cyclic by cylic
metabelian        | boolean  | extension of abelian by abelian
simple            | boolean  |
almost_simple     | boolean  | lies between a non-abelian simple group and its automorphism group
quasisimple       | boolean  | perfect group that is a central extension of a simple group
perfect           | boolean  | commutator subgroup equal to G
monomial          | boolean  | every complex irrep induced from a 1-d rep of some subgroup
rational          | boolean  | all characters are rational valued
Zgroup            | boolean  | all Sylow subgroups cyclic
Agroup            | boolean  | all Sylow subgroups abelian
pgroup            | smallint | 1 if trivial group, p if order a power of p, otherwise 0
elementary        | integer  | If the direct product of a cyclic group and a p-group, gives the product of all possible p.  If not, 1.
hyperelementary   | integer  | If the extension of a p-group by a cyclic group of order prime to p, gives the product of all possible p.  If not, 1.
rank              | smallint | the minimal size of a generating system of `G`.  Usually the same as `ngens`, but `rank` might be `NULL` if not known, or `ngens` may be `NULL` if no presentation given.
eulerian_function | numeric  | the ratio of the number of generating tuples with cardinality equal to the rank by the size of the automorphism group
center_label      | text     | Label for the isomoprhism class of the center Z
central_quotient  | text     | Label for the isomorphism class of G/Z
commutator_label  | text     | Label for the isomorphism class of the commutator subgroup
abelian_quotient  | text     | Label for the isomorphism class of the maximal abelian quotient
commutator_count  | integer  | The minimal integer l so that every element of the commutator subgroup can be written as a product of at most l commutators
frattini_label    | text     | Label for the isomorphism class of the Frattini subgroup
frattini_quotient | text     | Label for the isomorphism class of the Frattini quotient
transitive_degree | integer  | Smallest transitive degree in which this group arises
faithful_reps     | integer[]| The list of triples (d, s, m), where d is the dimension, s the Schur indicator and m the number of faithful irreducible representations with dimension d and Schur indicator s
smallrep          | integer  | Dimension of the smallest faithful irreducible rep (0 if center non-cyclic, `NULL` if unknown)
aut_order         | numeric  | Order of the automorphism group
aut_group         | text     | Label for the automorphism group (might be null if not in database)
outer_order       | numeric  | Order of the outer automorphism group
outer_group       | text     | Label for the outer automorphism group (might be null if not in database)
factors_of_aut_order | integer[] | List of primes dividing the order of the automorphism group
nilpotency_class  | smallint | The smallest n such that G has a central series of length n (-1 if not nilpotent)
ngens             | smallint | Number of generators in the presentation (`NULL` if no presentation available)
pc_code           | numeric  | Encoded pcgs from which relations can be recovered
number_conjugacy_classes | integer | Number of conjugacy classes of elements
number_subgroup_classes  | integer | Number of conjugacy classes of subgroups
number_subgroups  | integer  | Number of subgroups
number_normal_subgroups  | integer | Number of normal subgroups
number_characteristic_subgroups | integer | Number of characteristic subgroups
derived_length    | smallint | The number of steps in the derived series (0 for a perfect group)
primary_abelian_invariants | integer[] | Invariants of the maximal abelian quotient, as a sorted list of prime powers
smith_abelian_invariants | integer[] | Invariants of the maximal abelian quotient, as a sorted list of integers, each dividing the next
schur_multiplier  | integer[] | Smith invariants for the Schur multiplier (H_2(G, Z))
order_stats       | numeric[] | List of pairs `(o, m)` where `m` is the number of elements of order `o`.
elt_rep_type      | smallint  | Code for the main way that elements are encoded in conjugacy class and subgroup tables.  0=generators+relations, -n=permutation rep of degree n, 1=integer matrices, q=matrices over GF(q)
perm_gens     | numeric[] | encoded generators for a minimal permutation representation of this group (NULL if abelian or transitive degree too large)
gens_used     | smallint[] | Sorted list of generators used (1-based indexing going from larger to smaller in the filtration; other generators are powers of these; NULL if not solvable)
all_subgroups_known   | boolean   | Whether we store all subgroups of this group
normal_subgroups_known | boolean   | Whether we store all normal subgroups of this group
maximal_subgroups_known | boolean  | Whether we store all maximal subgroups of this group
sylow_subgroups_known | boolean  | Whether we store all sylow subgroups of this group
subgroup_inclusions_known | boolean | Whether we store inclusion relationships among subgroups of this group
outer_equivalence | boolean   | Whether subgroups are stored up to automorphism (as opposed to up to conjugacy)
subgroup_index_bound | smallint  | If not `NULL`, we store all (equivalence classes of) subgroups of index up to this bound.  Additional subgroups may also be stored (for example, normal subgroups, maximal subgroups, or subgroups of small order)
moddecompuniq | jsonb    | &#x1F534; &#x1F534;  Not added to db yet.  See Galois groups data eg: 3T2  
wreath_product | boolean | whether this group is a wreath product
central_product | boolean | whether this group is a central product
finite_matrix_group | boolean | whether this group shows up in `gps_prep_names`
direct_product  | boolean | whether this group can be expressed as a nontrivial direct product
semidirect_product  | boolean | whether this group can be expressed as a nontrivial semidirect product
composition_factors | text[]  | LMFDB labels for the composition factors, sorted by order then id.
composition_length  | smallint | the number of composition factors

`gps_families`: Names for families of groups

Here we list information common to all elements of a family of groups (like the dihedral or alternating groups).  We don't list descriptions in terms of extensions or products (stored in the `gps_subgroups`, `gps_central_products` and `gps_wreath_products`), or classical matrix groups over finite fields (stored in `gps_prep_names`).

Column        | Type     | Notes
--------------|----------|------
family        | text     | For example `D` for dihedral or `A` for alternating
knowl         | text     | Knowl for this family or special group
name          | text     | description of family
tex_name      | text     | As formattable string, for example C_{{{n}}}
priority      | smallint | Which position this alias should appear in the list of aliases for the group. 
magma_cmd | text     | As formattable string, for example CyclicGroup({n})


`gps_special_names`: Connection between common names for groups. Again, we don't list descriptions in terms of extensions or products (stored in the `gps_subgroups`, `gps_central_products` and `gps_wreath_products`), or classical matrix groups over finite fields (stored in `gps_prep_names`).

Column        | Type     | Notes
--------------|----------|------
label         | text     | Abstract isomorphism class of the group
family        | text     | For example `D` for dihedral or `A` for alternating
parameters    | jsonb    | To be used in formatting


## Permutation groups

`gps_transitive`: Transitive group labels, as in GAP and Magma.

There are 4952 transitive groups up to n=23.

Note that we can recover siblings by doing another search for transitive groups with the same abstract group label.


&#x1F534; &#x1F534; This doesn't match transitive database currently. Since transitive is in production we should update the schema here first to match, before modifying database.

Column        | Type     | Notes
--------------|----------|------
label         | text     | Label is of the form `nTt` where `n` is the degree and `t` is the "t-number"
group         | text     | The label for the abstract group
n             | smallint | The degree (`n` from `S_n`)
t             | integer  | The `t`-number, a standard index for conjugacy classes of subgroups of `S_n`
order         | numeric  | The size of the group
parity        | smallint | 1 if the group is a subgroup of A_n, otherwise -1
abelian       | boolean  | (include?)
cyclic        | boolean  | (include?)
solvable      | boolean  | (include?)
primitive     | boolean  | preserves no nontrivial partition of `{1,...,n}`
auts          | smallint | The number of automorphisms of a degree `n` field with this as its Galois group
arith_equiv   | smallint | Number of arithmetically equivalent fields for number fields with this Galois group
sibling_completeness | smallint | index bound up to which siblings are complete
quotients_complenetess | smallint | index bound up to which quotients are complete
subs          | jsonb    | If `K` is a degree `n` field with this Galois group, this gives the subfields up to isomorphism in terms of their Galois groups
quotients     | jsonb    | Low degree resolvents, up to isomorphism, for a field with this Galois group
generators    | numeric[] | generators for this transitive group


`gps_perm`: Permutation groups, both transitive and intransitive

Column        | Type     | Notes
--------------|----------|------
label         | text     | Label of this permutation group
group         | text     | The label for the abstract group
sn_subgroup   | text     | The short label for the corresponding subgroup of `S_n` in the gps_subgroups table
n             | smallint | The degree (`n` from `S_n`)
t             | integer  | The `t`-number, a standard index for conjugacy classes of transitive subgroups of `S_n`.   NULL if not transitive.
order         | numeric  | The size of the group
parity        | smallint | 1 if the group is a subgroup of A_n, otherwise -1
orbits        | smallint | the number of orbits in the natural action on `{1,...,n}`; will be 1 for transitive groups
transitive    | boolean  | whether this group is transitive
primitive     | boolean  | preserves no nontrivial partition of `{1,...,n}`
abelian       | boolean  | whether this group is abelian
cyclic        | boolean  | whether this group is cyclic
solvable      | boolean  | whether this group is solvable
nilpotency_class | smallint | the nilpotency class of this group
auts          | smallint | The number of automorphisms of a degree `n` field with this as its Galois group. NULL if not transitive
arith_equiv   | smallint | Number of arithmetically equivalent fields for number fields with this Galois group. NULL if not transitive
sibling_completeness | smallint | index bound up to which siblings are complete
quotients_complenetess | smallint | index bound up to which quotients are complete
subs          | jsonb    | If `K` is a degree `n` field with this Galois group, this gives the subfields up to isomorphism in terms of their Galois groups.  NULL if not transitive
quotients     | jsonb    | Low degree resolvents, up to isomorphism, for a field with this Galois group
generators    | numeric[] | generators, as encoded permutations of degree n

## Subgroups

`gps_subgroups`: subgroups/short exact sequences of finite groups

Each row in this table corresponds to a subgroup relationship `H <= G`.  When `H` is normal, we write `Q` for the quotient `G/H`.

There are two different notions of equivalence used, indicated in the column `outer_equivalence`.
If `False`, then subgroups are considered equivalent if they are related by conjugation (inner automorphism) within `G`.
If `True`, then subgroups are considered equivalent if they are related an automorphism of `G`.
For a given `G`, all subgroups will be considered up to the same notion of equivalence.

Currently, we use `outer_equivalence` only when `G` is abelian with more than 70 subgroups.

We aim to have (up to equivalence)
* All normal subgroups for each G in `gps_groups`
* All maximal subgroups for each G in `gps_groups`
* All subgroups when feasible

Subgroups can have two kinds of labels.  The normal label is computed in the subgroup_labels.m file, and includes the index and Gassman equivalence classes.  For groups where we only compute subgroups up to a certain index bound, we also provide special labels for subgroups we want to store that lie outside that index range.  These special labels are as follows.  In each case we start with the label of the abstract group.
* The center is labeled Z.
* The perfect core (the end of the derived series) is labeled PC
* The commutator/derived subgroup is labeled D.
* The Fitting subgroup is labeled F.
* The Frattini subgroup is labeled Phi.
* The radical is labeled R.
* The socle is labeled S.
* The chosen transitive subgroup (namely, one with minimal index and trivial core) is labeled T.
* Series are labeled with a letter and then an integer:
  * U0 > U1 > ... is the upper central series: `U_i/U_{i+1} = Z(G/U{i+1})`
  * L0 > L1 > ... is the lower central series: `L_{i+1} = [G, L_i]`
  * D0 > D1 > ... is the derived series: each term is the commutator of the previous
  * C0 > C1 > ... is a chief series: normal series that cannot be refined

Column            | Type      | Notes
------------------|-----------|------
label             | text      | `N.i.m.g.j` where `N.i` is the label of `G`, `m` is the index`, `g` is a counter over Gassman equivalence classes and `j` is a counter within classes
special_labels    | text[]    | Labels for normal subgroups, maximal subgroups and others (such as the center, Frattini...) that are below the index bound.
outer_equivalence | boolean   | whether subgroups of `G` are considered up to outer equivalence (vs conjugacy)
aut_counter       | integer   | The minimum `j` equivalent to this under automorphism (`NULL` if `outer_equivalence` true)
extension_counter | integer   | A numeric label for varying `G` among extensions with fixed `H`, `Q` and `split` (matching [groupnames](groupnames.org)?)
subgroup          | text      | Label for `H` as an abstract group
subgroup_order    | numeric   | Order of `H` (include?)
ambient           | text      | Label for `G`
ambient_order     | numeric   | Order of `G` (include?)
quotient          | text      | Label for `Q` as an abstract group (`NULL` if `H` not normal)
quotient_order    | numeric   | Order of `Q` (include?)
normal            | boolean   | Whether `H` is normal in `G`
characteristic    | boolean   | Whether `H` is a characteristic subgroup of `G`
cyclic            | boolean   | whether `H` is cyclic (include?)
abelian           | boolean   | whether `H` is abelian (include?)
perfect           | boolean   | whether `H` is perfect (include?)
sylow             | smallint  | if the order of `H` is a power of `p` and coprime to the order of `Q`, stores `p`.  Otherwise, `0`.
hall              | numeric   | if the order of `H` is coprime to the order of `Q`, stores the radical of the order of `H`. Otherwise, `0`.
maximal           | boolean   | whether `H` is a maximal subgroup of `G`
maximal_normal    | boolean   | whether `H` is a maximal NORMAL subgroup of `G` (may not be maximal)
minimal           | boolean   | whether `H` is a minimal subgroup of `G`
minimal_normal    | boolean   | whether `H` is a minimal NORMAL subgroup of `G` (may not be minimal)
mobius_function	  | integer   | the value of the mobius function of `H` wrt the subgroup lattice of the containing group `G`
split             | boolean   | whether this sequence is split (null for non-normal)
complements       | text[]    | a list of subgroups `K` (up to equivalence) that intersect trivially with `H` and so that `G = HK`
direct            | boolean   | whether this sequence is a direct product (`NULL` for non-normal)
central           | boolean   | whether `H` is contained in the center of `G`
stem              | boolean   | whether `H` is contained in both the center and commutator subgroups of `G`
count             | numeric   | The number of subgroups of `G` equivalent to `H`
conjugacy_class_count | numeric   | The number of conjugacy classes of subgroups in this equivalence class (`NULL` if `outer_equivalence` is false)
core              | text     | the subgroup label for the core: the intersection of all conjugates of `H`
coset_action_label| text      | when `H` has trivial core `C` and the size of `Q` is at most 31 (GAP)/47 (Magma), gives the transitive group label for `G` as a permutation representation on `G/H`; `NULL` otherwise
normalizer        | text   | the label of the normalizer of `H` in `G`
centralizer       | text      | the label of the centralizer of `H` in `G`
normal_closure    | text   | the label of the smallest normal subgroup of `G` containing `H`
quotient_action_kernel | text   | the subgroup label of the kernel of the map from `Q` to `A` (`NULL` if `H` is not normal).  Here `A = Aut(H)` when the sequence is split or `H` is abliean, and `A = Out(H)` otherwise
quotient_action_image | text  | the label for `Q/K` as an abstract group, where `K` is the quotient action kernel (NULL if `H` is not normal)
contains          | text[] | A sorted list of labels for the maximal subgroups of `H`, up to equivalence (`NULL` if unknown)
contained_in      | text[] | A sorted list of labels for the minimal subgroups of `G` containing `H`, up to equivalence (`NULL` if unknown) (include?)
quotient_fusion   | jsonb     | A list of lists: for each conjugacy class of `Q`, lists the conjugacy classes in `G` that map to it (`NULL` if unknown)
subgroup_fusion   | integer[] | A list: for each conjugacy class of `H`, gives the conjugacy class of `G` in which it's contained
alias_spot        | smallint  | Which position this alias should appear in the list of aliases for the group.  0 indicates that it's the main name; `NULL` if not normal (or if it shouldn't be displayed; we only want to display one of the two orders for a direct product)
generators        | numeric[] | Encoded elements that generate `H` together.  Elements are encoded according to the groups `elt_rep_type` attribute
generator_images  | numeric[] | If the subgroup is normal, the images of the generators as encoded elements of the quotient group.  May also be null if the quotient group is large enough that we don't find an isomorphism
standard_generators| boolean  | Whether the given generators are the same as the generators for the abstract group associated to this subgroup (and thus define an inclusion homomorphism)
projective_image  | text      | label for the quotient by the center of the ambient group
diagram_x         | integer   | integer from 1 to 10000 indicating the x-coordinate for plotting the subgroup in the lattice, 0 if not computed

## Other products

Direct products, semidirect products and non-split extensions are described well by the `gps_subgroups` table, but there are some other types of products that are not.

`gps_central_products`: Central products of groups

If `Z(G_1)` and `Z(G_2)` contain a common nontrivial subgroup `U` then the quotient `G_1 x G_2 / U` by the diagonally embedded `U` is the central product `G_1 o G_2`.

If there are multiple choices of U that yield isomorphic central products, we choose the lowest numbered subgroup label in `G_1`, then the lowest numbered subgroup label in `G_2`.

&#x1F534; &#x1F534; Table not yet in database.


Column         | Type      | Notes
---------------|-----------|------
factor1        | text      | label for `G_1`, lexicographically smaller (ie, smaller order or same order and smaller `i`
factor2        | text      | label for `G_2`, lexicographically larger
sub1           | text      | subgroup label for `U < G_1`
sub2           | text      | subgroup label for `U < G_2`
product        | text      | label for the product
alias_spot     | smallint  | Which position this alias should appear in the list of aliases for the product.  0 indicates that it's the main name

`gps_wreath_products`: Wreath products of groups

The wreath product of an abstract group `G` and a permutation group `P` of degree `n` is the semidirect product of `G^n` with `P`, where `P` acts by permuting the copies of `G`.


&#x1F534; &#x1F534; Table not yet in database.

Column         | Type      | Notes
---------------|-----------|------
acted          | text      | label for `G` as an abstract group
actor          | text      | label for `P` as a permutation group
product        | text      | label for the product
alias_spot     | smallint  | Which position this alias should appear in the list of aliases for the product.  0 indicates that it's the main name

## Subgroups of `GLnQ`

`gps_qrep`: Finite subgroups of GL_n(Z), up to GL_n(Q) conjugacy

Note that every finite subgroup of GL_n(Q) is conjugate to one within GL_n(Z),
so we use the `gps_zrep` table to store actual matrices.  (Actually, the entry gens will hold a copy for now.)


Column         | Type      | Notes
---------------|-----------|------
label          | text      | label of the "first" character giving this subgroup as its image
carat_label    | text      | `n.i`, where `n` is the dimension, `i` is an index for the Q-class as in the CARAT GAP package (see Hoshi-Yamasaki, Rationality Problem for Algebraic Tori for examples)
dim            | smallint  | Dimension `n`
order          | numeric   | The size of the group
group          | text      | The LMFDB id for the abstract group
c_class        | text      | The LFMDB id for the subgroup class in `GL_n(C)`
irreducible    | boolean
gens           | integer[] | List of matrices generating group, matching the generators in the `gps_groups` table
decomposition  | jsonb     | List of pairs `(label, m)` giving the decomposition as a direct sum of irreducible Q[G]-modules.  `label` is the label for the corresponding `GL_n(Q)`-class, and `m` the multiplicity

## Subgroups of `GLnZ`

`gps_zrep`: Finite subgroups of GL_n(Z), up to GL_n(Z) conjugacy

For `G < GL_n(Z)`, let `F(G)` be the set of symmetric nxn real matrices `F` with `g^t F g = F` for all `g` in `G`.
Let `B(G)` be the set of `b` in `GL_n(Z)` with `b^t F b = F` for all `F` in `F(G)`.  Then `G` and `G'` are Bravais equivalent if `B(G)` is conjugate in `GL_n(Z)` to `B(G')`.


Column         | Type      | Notes
---------------|-----------|------
label          | text      | `n.i.j`, where `n` is the dimension, `i` is an index for the Q-class and `j` is an index for the Z-class as in CARAT (see Hoshi-Yamasaki, Rationality Problem for Algebraic Tori for examples)
dim            | smallint  | 
order          | numeric   | The size of the group
group          | text      | The LMFDB id for the abstract group
q_class        | text      | The label for the `GL_n(Q)` class containing this class
c_class        | text      | The label for the `GL_n(C)` class containing this class
bravais_class  | text      | The label for the Z-class of the Bravais group B(G) (see Def. 2.8 of Opgenorth, Pleskin, Shulz Crystalographic Algorithms and Tables)
crystal_symbol | text      | The symbol for the crystal family (see Def. 2.11, 2.12 of Opgenorth, Pleskin, Shulz)
indecomposible | boolean   | Whether the corresponding `Z[G]`-module splits up as a direct sum (the pieces don't necessarily need to be faithful representations)
irreducible    | boolean   | Whether the corresponding `Q[G]`-module splits up as a direct sum (the pieces don't necessarily need to be faithful representations)
decomposition  | jsonb     | List of pairs `(label, ker, m)` giving the decomposition of `Z^n` as a direct sum of indecomposible submodules.  Here `m` is the multiplicity and `ker` is an integer giving the subgroup label for the kernel of the representation.
gens           | integer[] | List of matrices generating group, matching the generators in the `gps_groups` table

## Subgroups of `GLnC`

`gps_crep`: Finite subgroups of GL_n(C), up to GL_n(C) conjugacy


&#x1F534; &#x1F534; Question: Should we only include irreducible representations?

Column         | Type      | Notes
---------------|-----------|------
label          | text      | label of the first character having this group as its image
dim            | smallint  | 
order          | numeric   | The size of the group
group          | text      | The label for the abstract group
irreducible    | boolean
decomposition  | jsonb     | List of triples `(label, ker, m)` where `label` is the label of a subgroup of lower dimension, `ker` is the kernel of the map to that subgroup and `m` is the multiplicity.  (JJ: not including ker for now since I don't think it makes sense.  ker is relative to an abstract group, but this is just a subgroup of GL(n,C), so it is just a sum of irreducible subgroups.)
indicator      | smallint  | the Frobenius-Schur indicator
schur_index    | smallint  | The ratio of the minimal degree of a number field containing all matrix entries by the degree of the number field generated by the traces
cyc_order_mat  | integer   | an integer m so that the entries in the `gens` column lie in `Q(\zeta_m)`
trace_field    | int[]      | list of coefficients of a polredabs'ed polynomial defining the field generated by the traces
cyc_order_traces | integer | an integer m so that the entries in the `traces` column lie in `Q(\zeta_m)`
denominators   | integer[] | A list of denominators for the matrix images, with the order matching the generators in the `gps_groups` table.
gens           | jsonb     | A list of scaled matrices generating the group, with the order matching the generators in the `gps_groups` table.  The entries are encoded as lists of pairs `(c, e)` representing the sum of `c*zeta_m^e` (divided by the corresponding denominator in the `denominators` column).  Here `m` is the value of the `cyc_order_mat` column, `c >= 0` and `0 <= 2e < m`.
traces         | jsonb | The traces of the conjugacy classes (in the order of `gps_groups_cc`), encoded as lists of pairs `(c, e)` as above, but using the `m` from `cyc_order_traces`.

## Subgroups of finite matrix groups

`gps_prep`: Subgroups of classical groups over finite fields, up to conjugacy within the ambient group

Initially this table would contain subgroups of `GL_n(F_q)`, but it can easily incorporate subgroups of other groups such as `SL_n`, `Sp_n`, `GSp_n`, and `SO_n`.  Since the main point of this table is to give generators as matrices, it doesn't make sense to extend to exceptional groups of Lie type.


&#x1F534; &#x1F534; Table not yet in database.


Column         | Type       | Notes
---------------|------------|------
label          | text       | `n.q.N.i.j` where `n` is the dimension, `q` is the cardinality of the finite field, `N.i` is the label of the ambient group and `j` is the subgroup identifier from `gps_subgroups`.
dim            | smallint   | The dimension of the vector space on which the ambient group acts
q              | smallint   | The cardinality of the finite field
prime          | boolean    | Whether the cardinality is prime
ambient        | text       | Group label `N.i` for the ambient group
counter        | integer    | Subgroup identifier from `gps_subgroups`
projective_image | text       | label for the quotient by the center of the ambient group
gens           | smallint[] | Matrices generating the group, in order corresponding to the generators listed in `gps_groups`.  If `q` is prime, the entries are integers `c` with `-q < 2c <= q`.  Otherwise, they are lists of integers giving the coefficients for the element as a polynomial (with respect to the Conway polynomial defining the field extension)
proj_label | text | The label `N.i.j` of the image of the group in the quotient of the ambient group by its subgroup of scalars, where `N.i` is the label of the quotient and `j` is the subgroup identifier.

`gps_prep_names`: Names for classical groups with a specified `n` and `q`


&#x1F534; &#x1F534; Table not yet in database.

Column         | Type       | Notes
---------------|------------|------
group          | text       | label of abstract group
dim            | smallint   | The dimension of the vector space on which the ambient group acts
q              | smallint   | The cardinality of the finite field
family         | text       | For example `GL` or `Spin`
name           | text       |
tex_name       | text       |



# Conjugacy classes

## Conjugacy classes in abstract groups

`gps_groups_cc`: Conjugacy classes in groups

The number of non-central conjugacy classes for groups of order up to 15 (26), 31 (271), 63 (2324), 127 (20451), 255 (219699).  So we guess about 2 million up to 511, 20 million up to 1023 and 200 million up to 2047.

The number of non-central conjugacy classes for groups of order not a power of 2: up to 15 (20), 31 (214), 63 (1795), 127 (15180), 255 (144996).

Big contributors above 10, up to 255 (fraction of count so far): 128 (77%), 64 (67%), 16 (66%), 32 (64%), 12 (50%), 24 (42%), 48 (37%), 96 (35%), 192 (34%), 18 (17%), 14 (15%), 20 (15%), 40 (13%), 36 (11%), 80 (11%), 30 (10%), 72 (10%), 54 (9%), 160 (8%), 56 (8%).
Number of central elements up to           15 (173), 31 (907), 63 (4292), 127 (21255), 255 (115353)
Number of elements in abelian groups up to 15 (161), 31 (794), 63 (3469), 127 (15249), 255 (64885), 511 (268613), 1023 (1106900), 2047 (4531226)

As for subgroups, for large abelian groups we instead store orbits under the full automorphism group (rather than orbits under the inner automorphism group, which are conjugacy classes).

Column        | Type       | Notes
--------------|------------|------
label         | text       | `N.i.oJ` where `N.i` is the label for the group, `o` is the order of elements in this class and `J` is a capital letter code
group         | text       | Label for the ambient group
size          | integer    | Number of elements in this conjugacy class/orbit
counter       | integer    | 1-based ordering of classes (agree with GAP/Magma?).  Sorted by order of representative, then size of the class, then group power classes together.  We choose a smallest representative for each power class
order         | integer    | Order of an element in this class
centralizer   | text       | Label for the centralizer of an element in this class, as a subgroup
powers        | integer[]  | which `counter` conjugacy class for the image of the pth power map, for p dividing the order of the group or the Euler phi function of the exponent of the group
representative | numeric    | An encoded representative for this conjugacy class, using the group's elt_rep_type

## Conjugacy classes in permutation groups

`gps_transitive_cc`: Conjugacy classes in transitive permutation groups

Up to degree 23, there are 291985 non-central classes, 9283 central elements.

&#x1F534; &#x1F534; Table not yet in database.

Column        | Type       | Notes
--------------|------------|------
label         | text       | `N.i.oJ` where `N.i` is the label for the abstract group (should it be the transitive label?), `o` is the order of elements in this class and `J` is a capital letter code
group         | text       | transitive label of the group
degree        | smallint   | the degree of the group (`n` from `S_n`)
counter         | smallint?  | 1-based ordering of conjugacy classes (agree with GAP/Magma?)
size          | numeric    | Number of elements in this conjugacy class
order         | smallint   | Order of an element in this conjugacy class
centralizer   | text       | Label for the centralizer of an element in this conjugacy class, as a subgroup of the group
cycle_type    | smallint[] | sizes of the cycles in a permutation in this class, in descending order and omitting 1s
rep           | numeric    | a representative element, as the index in the lexicographic ordering of `S_n`.  This is computed by Sage's `Permutations(n).rank(sigma)` function, with inverse `Permutations(n).unrank(rep)` (using Lehmer codes)

# Characters

`gps_char`: Irreducible complex characters of groups

TODO: Should we also support just counting the characters with a given kernel and image, as is done for [C2xC88](https://people.maths.bris.ac.uk/~matyd/GroupNames/163/C2xC88.html) for example?  This might be done by having an option to specify the isomorphism type of the kernel and a count of such characters rather than giving the actual subgroup.

Column         | Type       | Notes
---------------|------------|------
label          | text       | `N.i.dcj` where `N.i` is the label for the group, `d` is the dimension, `c` is a lower-case letter code for the rational class of this character, and `j` is an enumeration of characters within that rational class (`j` is omitted if the rational class is a singleton)
group          | text       | LMFDB label `N.i` for the group (domain of the homomorphism to GL_n(C))
dim            | smallint   | `d`, the dimension of the representation
counter        | smallint   | `j`, a 1-based ordering of characters of this group, sorted lexicographically by value (currently not `j`, but runs through all the characters giving their display order)
kernel         | text       | The subgroup label for the kernel of this character
center         | text       | The subgroup label for the subgroup that this character maps into the diagonal matrices
faithful       | boolean    | Whether the corresponding homomorphism is injective
q_character    | text       | Label of the corresponding Q-character
indicator      | smallint   | the Frobenius-Schur indicator
image          | text       | The label for the image as a subgroup of GL_n(C)
nt             | int[]      | the pair [n,t] where nTt is the smallest permutation representation containing the character
cyclotomic_n   | integer    | Conductor of the field generated by character values
values         | jsonb      | a list character values in the order of the conjugacy classes.  Individual character values are given in the [[c,e],..] encoding
field          | int[]      | list of coefficients of a polredabs'ed polynomial defining the field generated by the trace values
group_order    | numeric    | order of the corresponding group (for search returns)

## Q-characters

`gps_qchar`: Irreducible rational characters of groups

Column         | Type       | Notes
---------------|------------|------
label          | text       | `N.i.dc` where `N.i` is the label for the group, `d` is the complex dimension of a character in this orbit, `c` is a lower-case letter code enumerating classes with the same dimension (sorted lexicographically by values on the power classes)
group          | text       | LMFDB label `N.i` for the group (domain of the homomorphism to GL_n(Q))
cdim           | smallint   | the complex dimension of a character in this rational orbit
qdim           | smallint   | the rational dimension (value at 1), equal to `cdim*multiplicity`
multiplicity   | smallint   | the number of complex characters in this rational orbit
schur_index    | smallint   | The ratio of the minimal degree of a number field containing all matrix entries by the degree of the number field generated by the traces
image          | text       | The label for the image as a subgroup of GL_n(Q)
counter        | smallint   | a 1-based ordering of characters of this group giving their display order
faithful       | boolean    | Whether the corresponding homomorphism is injective
nt             | int[]   | the pair [n,t] where nTt is the smallest permutation representation containing the character
qvalues        | int[]      | a list character values
group_order    | numeric    | order of the corresponding group (for search returns)

## Hashes

`gps_smallhash`: Hash values for small groups to use in idenfication

Column         | Type       | Notes
---------------|------------|------
order          | integer    | order of the group supports up to 73^5 (217 groups), 31^6 (4540 groups) or 11^7 (750,735 groups)
counter        | integer    | counter for groups of this order.  1-indexed for SmallGroups, 0-indexed for orders not in the SmallGroup database
hash           | bigint     | the hash value
