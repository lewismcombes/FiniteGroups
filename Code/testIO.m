G := New(LMFDBGrp);
G`MagmaGrp := SmallGroup(24,3);
G`label := "test";
AssignBasicAttributes(G);
test_attrs := [
                "order",
                //"counter",
                "factors_of_order",
                "exponent",
                "abelian",
                "cyclic",
                "solvable",
                "supersolvable",
                "nilpotent",
                "metacyclic",
                "metabelian",
                "simple",
                "almost_simple",
                "quasi_simple",
                "perfect",
                "monomial",
                "rational",
                "Zgroup",
                "Agroup",
                "pgroup"
              ];
for attr in test_attrs do
  print attr;
  Get(G, attr);
end for;
SaveLMFDBObject(G : attrs:=test_attrs, sep:="|");
