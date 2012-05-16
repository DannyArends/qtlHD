/**
 * test reading data and then apply HMM
 * (intercross example: listeria)
 */

module test.hmm.test_hmm_f2;

import std.math, std.stdio, std.path;
import std.exception, std.conv;
import std.random;
import std.algorithm;

import qtl.core.primitives;
import qtl.core.phenotype, qtl.core.chromosome, qtl.core.genotype;
import qtl.plugins.qtab.read_qtab;
import qtl.core.map.make_map, qtl.core.map.map;
import qtl.core.map.genetic_map_functions;
import qtl.core.hmm.f2;


unittest {
  writeln("Unit test " ~ __FILE__);
}

unittest {
  alias std.path.buildPath buildPath;
  auto dir = to!string(dirName(__FILE__) ~ dirSeparator ~
                       buildPath("..","..","..","..","test","data", "input", "listeria_qtab"));

  // load founder info
  auto founder_fn = to!string(buildPath(dir, "listeria_founder.qtab"));
  writeln("reading ", founder_fn);
  auto info = get_section_key_values(founder_fn,"Set Founder");
  assert(info["Cross"] == "F2");
  assert(info["Phase"] == "unknown");

  // load symbols
  auto symbol_fn = to!string(buildPath(dir,"listeria_symbol.qtab"));
  // First read symbol information (the GenotypeCombinators)
  writeln("reading ",symbol_fn);
  auto fs = File(symbol_fn,"r");
  auto symbols = read_genotype_symbol_qtab(fs);

  // Test working of symbols
  assert(symbols.decode("A") == symbols.decode("AA"));
  assert(to!string(symbols.decode("NA")) == "[NA]");
  assert(to!string(symbols.decode("A")) == "[(0,0)]");
  assert(to!string(symbols.decode("H")) == "[(0,1), (1,0)]");
  assert(to!string(symbols.decode("B")) == "[(1,1)]");
  assert(to!string(symbols.decode("HorA")) == "[(0,0), (0,1), (1,0)]");
  assert(to!string(symbols.decode("HorB")) == "[(0,1), (1,0), (1,1)]");

  // Read genotype matrix
  auto genotype_fn = to!string(buildPath(dir,"listeria_genotype.qtab"));
  writeln("reading ",genotype_fn);
  auto fg = File(genotype_fn,"r");
  auto ret = read_genotype_qtab(fg, symbols);
  auto individuals = ret[0];
  auto genotype_matrix = ret[1];

  // Show the first individual and genotypes
  assert(individuals.list.length == 120);
  assert(individuals.list[15].name == "16");
  assert(genotype_matrix[119].length == 133);

  // by symbol
  assert(genotype_matrix[0][0] == symbols.decode("B"));
  assert(genotype_matrix[0][3] == symbols.decode("H"));

  assert(genotype_matrix[15][0] == symbols.decode("H"));
  assert(genotype_matrix[15][130] == symbols.decode("HorB"));

  assert(genotype_matrix[18][129] == symbols.decode("B"));
  assert(genotype_matrix[18][130] == symbols.decode("NA"));
  assert(genotype_matrix[18][131] == symbols.decode("A"));

  // by founders
  assert(genotype_matrix[0][0].list[0].homozygous == true);
  assert(genotype_matrix[0][0].list[0].heterozygous == false);
  assert(genotype_matrix[0][0].list[0].founders[0] == 1);
  assert(genotype_matrix[0][0].list[0].founders[1] == 1);

  assert(genotype_matrix[0][3].list[0].homozygous == false);
  assert(genotype_matrix[0][3].list[0].heterozygous == true);
  assert(genotype_matrix[0][3].list[0].founders[0] == 0);
  assert(genotype_matrix[0][3].list[0].founders[1] == 1);

  assert(genotype_matrix[15][0].list[0].homozygous == false);
  assert(genotype_matrix[15][0].list[0].heterozygous == true);
  assert(genotype_matrix[15][0].list[0].founders[0] == 0);
  assert(genotype_matrix[15][0].list[0].founders[1] == 1);

  assert(genotype_matrix[18][129].list[0].homozygous == true);
  assert(genotype_matrix[18][129].list[0].heterozygous == false);
  assert(genotype_matrix[18][129].list[0].founders[0] == 1);
  assert(genotype_matrix[18][129].list[0].founders[1] == 1);

  assert(genotype_matrix[18][131].list[0].homozygous == true);
  assert(genotype_matrix[18][131].list[0].heterozygous == false);
  assert(genotype_matrix[18][131].list[0].founders[0] == 0);
  assert(genotype_matrix[18][131].list[0].founders[1] == 0);

  // reading phenotypes
  auto pheno_fn = to!string(buildPath(dir,"listeria_phenotype.qtab"));
  writeln("reading ",pheno_fn);
  auto p_res = read_phenotype_qtab!(Phenotype!double)(pheno_fn);
  Phenotype!double[][] pheno = p_res[0];

  assert(pheno.length == 120);
  foreach(p; pheno) assert(p.length == 1);

  // 1st ind, 1st phenotype
  assert(pheno[0][0].value == 118.317);
  // 3rd ind, 1st phenotype
  assert(pheno[2][0].value == 194.917);
  assert(to!string(pheno[29][0]) == "NA"); // missing value

  // Marker map reader
  auto marker_map_fn = to!string(buildPath(dir,"listeria_marker_map.qtab"));
  writeln("reading ",marker_map_fn);
  auto markers = read_marker_map_qtab!(Marker)(marker_map_fn);
  assert(markers.length == 133);
  assert(markers[0].name == "D10M44");
  assert(markers[0].chromosome.name == "1");
  assert(markers[3].get_position == 40.4136);
  assert(markers[128].name == "D19M117");
  assert(markers[128].chromosome.name == "19");
  assert(markers[128].get_position == 16.364);

  // marker id == numeric index
  foreach(i, m; markers) assert(m.id == i);

  // test splitting up of markers into chromosomes
  //    note: chromosomes not necessarily ordered
  auto markers_by_chr = get_markers_by_chromosome(markers);
  foreach(chr; markers_by_chr) {
    // check that markers within chromosome are in order:
    //    contiguous ids; non-decreasing position
    assert(chr[1][0].chromosome.name == chr[0].name);
    for(auto i=1; i<chr[1].length; i++) {
      assert(chr[1][i].id == chr[1][i-1].id+1);
      assert(chr[1][i].get_position >= chr[1][i-1].get_position);
      assert(chr[1][i].chromosome.name == chr[0].name);
    }
  }

  auto markers_by_chr_sorted = sort_chromosomes_by_marker_id(markers_by_chr);
  Marker[] pmap_stepped, pmap_minimal;
  foreach(chr; markers_by_chr_sorted) {
    // check that markers within chromosome are in order:
    //    contiguous ids; non-decreasing position
    assert(chr[1][0].chromosome.name == chr[0].name);
    for(auto i=1; i<chr[1].length; i++) {
      assert(chr[1][i].id == chr[1][i-1].id+1);
      assert(chr[1][i].get_position >= chr[1][i-1].get_position);
      assert(chr[1][i].chromosome.name == chr[0].name);
    }

    pmap_stepped = add_stepped_markers_autosome(chr[1], 5.0, 0.0);
    pmap_minimal = add_minimal_markers_autosome(chr[1], 5.0, 0.0);
  }

  // test calc_geno_prob with listeria data, chr 4
  writeln("Test calc_geno_prob with listeria data, chr 4");
  auto chr4_map = markers_by_chr_sorted[3][1];
  auto rec_frac = recombination_fractions(chr4_map, GeneticMapFunc.Haldane);

  auto genoprobs = calc_geno_prob_F2(genotype_matrix, chr4_map, rec_frac, 0.002);

  /******************************
   * in R:

   data(listeria)
   for(i in seq(along=listeria$geno)) {
     m <- listeria$geno[[i]]$map
     listeria$geno[[i]]$map <- round(m, ifelse(m < 10, 5, 4))
   }
   listeria <- calc.genoprob(listeria, err=0.002, map="haldane")
   for(ind in c(1, 27, 120))
     print(paste0("genoprobs_from_rqtl = [",
                  paste(apply(listeria$geno[["4"]]$prob[ind,,], 1, function(a) paste0("[", paste(sprintf("%.20f", a), collapse=", "), "]")), collapse=", "),
                  "];"))

   *
   ******************************/

  double[][] genoprobs_from_rqtl;

  // probs from R/qtl for individual 1
  genoprobs_from_rqtl = [[0.99365258220779917320, 0.00536677960696724590, 0.00098063818523398574], [0.01597333397028120536, 0.98401049774880899879, 0.00001616828090931726], [0.98819059738489645195, 0.01083423736055390621, 0.00097516525454971611], [0.00156449607177869504, 0.99827438804771617686, 0.00016111588050444554]];  

  auto ind = 0;
  assert(genoprobs.length == genoprobs_from_rqtl.length);
  foreach(i; 0..genoprobs.length) {
    assert(genoprobs[i][ind].length == genoprobs_from_rqtl[i].length);
    foreach(j; 0..1) {
      assert(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]) < 1e-10,
             to!string(i) ~ "  " ~
             to!string(genoprobs[i][ind][j]) ~ "  " ~
             to!string(genoprobs_from_rqtl[i][j]) ~ "  " ~
             to!string(log10(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]))));
    }
  }

  // probs from R/qtl for ind'l 27
  genoprobs_from_rqtl = [[0.99572456085363969525, 0.00327771914550501397, 0.00099772000085535150], [0.44357685866023488508, 0.53992256196411336777, 0.01650057937565204552], [0.00084713351110069163, 0.99905404146062604109, 0.00009882502827408544], [0.00028922118598153989, 0.99942262138906567959, 0.00028815742495473404]];
  ind = 26;
  assert(genoprobs.length == genoprobs_from_rqtl.length);
  foreach(i; 0..genoprobs.length) {
    assert(genoprobs[i][ind].length == genoprobs_from_rqtl[i].length);
    foreach(j; 0..1) {
      assert(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]) < 1e-10,
             to!string(i) ~ "  " ~
             to!string(genoprobs[i][ind][j]) ~ "  " ~
             to!string(genoprobs_from_rqtl[i][j]) ~ "  " ~
             to!string(log10(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]))));
    }
  }
  
  // probs from R/qtl for ind'l 120
  genoprobs_from_rqtl = [[0.23363198854294833784, 0.53273602291410349086, 0.23363198854294822682], [0.21477497000974676844, 0.57045005998050635210, 0.21477497000974687946], [0.18276695221386124457, 0.63446609557227739984, 0.18276695221386132784], [0.00050050050050050071, 0.99899899899899902156, 0.00050050050050050071]];
  ind = 119;
  assert(genoprobs.length == genoprobs_from_rqtl.length);
  foreach(i; 0..genoprobs.length) {
    assert(genoprobs[i][ind].length == genoprobs_from_rqtl[i].length);
    foreach(j; 0..1) {
      assert(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]) < 1e-10,
             to!string(i) ~ "  " ~
             to!string(genoprobs[i][ind][j]) ~ "  " ~
             to!string(genoprobs_from_rqtl[i][j]) ~ "  " ~
             to!string(log10(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]))));
    }
  }
  

  // test calc_geno_prob with listeria data, chr 13
  writeln("Test calc_geno_prob with listeria data, chr 13");
  auto chr13_map = markers_by_chr_sorted[12][1];
  auto pmap_minimal_chr13 = add_minimal_markers_autosome(chr13_map, 1.0, 0.0);
  rec_frac = recombination_fractions(pmap_minimal_chr13, GeneticMapFunc.Kosambi);

  genoprobs = calc_geno_prob_F2(genotype_matrix, pmap_minimal_chr13, rec_frac, 0.01);

  /******************************
   * in R:

   data(listeria)
   for(i in seq(along=listeria$geno)) {
     m <- listeria$geno[[i]]$map
     listeria$geno[[i]]$map <- round(m, ifelse(m < 10, 5, 4))
   }
   listeria <- calc.genoprob(listeria, err=0.01, map="kosambi", step=1, stepwidth="max")
   for(ind in c(1, 27, 120))
     print(paste0("genoprobs_from_rqtl = [",
                  paste(apply(listeria$geno[["13"]]$prob[ind,,], 1, function(a) paste0("[", paste(sprintf("%.20f", a), collapse=", "), "]")), collapse=", "),
                  "];"))

   *
   ******************************/

  // probs from R/qtl for ind'l 1
  genoprobs_from_rqtl = [[0.00093947107625960398, 0.90558411629036694723, 0.09347641263337422290], [0.00143673628278441273, 0.90716611076223829802, 0.09139715295497738423], [0.00284269548888373700, 0.91261920421548403670, 0.08453810029563157968], [0.00395240827329715761, 0.91863684870278916605, 0.07741074302391390272], [0.00476316656224347410, 0.92522727764939738382, 0.07000955578835917070], [0.00527186613949289905, 0.93239950817225436541, 0.06232862568825337651], [0.00547500095801338200, 0.94016335341734613706, 0.05436164562464058242], [0.00536865690574284127, 0.94852943598618932874, 0.04610190710806810754], [0.00494850501646558125, 0.95750920246981618966, 0.03754229251371796888], [0.00420979411601392958, 0.96711493911016666036, 0.02867526677381966246], [0.00314734289324383743, 0.97735978861028893760, 0.01949286849646659700], [0.00175553138444746004, 0.98825776811637933150, 0.00998670049917382494], [0.00002829185906360500, 0.99982378839622554345, 0.00014791974471212432], [0.00034827697608168175, 0.99922765902610044542, 0.00042406399781799356], [0.00034281683234591346, 0.99928239547773700657, 0.00037478768991672820], [0.00001188288670022903, 0.99998806911357218663, 0.00000004799972708634], [0.00001273335891325602, 0.99998721865804607312, 0.00000004798304246031], [0.16640051348570888967, 0.83319365802336298188, 0.00040582849092848716], [0.33256145562981453967, 0.66691830951651742687, 0.00052023485366803595], [0.49865714107855779735, 0.50090256688409262598, 0.00044029203734922111], [0.66484897433273848488, 0.33488822763488579337, 0.00026279803237497153], [0.83129839645540981596, 0.16861709146035977480, 0.00008451208423047219], [0.99816709843359330279, 0.00183055865849329844, 0.00000234290791413904], [0.99857001668520317672, 0.00142877194844409682, 0.00000121136635273716], [0.99917244060904486513, 0.00082717019334513093, 0.00000038919760998130], [0.99997467040259235826, 0.00002527333486086176, 0.00000005626254644545], [0.99940976291048444491, 0.00059011829345908379, 0.00000011879605689591], [0.99922487609915811024, 0.00077495921785188256, 0.00000016468298988366], [0.99941983421793822995, 0.00058007728655026553, 0.00000008849551185294], [0.99999482257527672058, 0.00000517604674517197, 0.00000000137797747915], [0.99991240696087180240, 0.00008759064421436322, 0.00000000239491315976], [0.99999701765677528886, 0.00000298188250862147, 0.00000000046071588527], [0.99977307437441531590, 0.00022691252940187630, 0.00000001309618227604], [0.99977403607549575337, 0.00022595103945125257, 0.00000001288505279842], [0.99999990330085108958, 0.00000009654738680160, 0.00000000015176226783], [0.99999989730634541996, 0.00000010254177301965, 0.00000000015188087766], [0.99861476440920760034, 0.00138429973782670432, 0.00000093585296610758], [0.99759777725941722881, 0.00239895406706655111, 0.00000326867351589371], [0.99694800333274069537, 0.00304555622484908124, 0.00000644044241103091], [0.99666484774664199087, 0.00332505617689790242, 0.00001009607646016828], [0.99674805251843434650, 0.00323786455496086331, 0.00001408292660535025], [0.99719769624428256094, 0.00278385326009609503, 0.00001845049562126714], [0.99801419419865466942, 0.00196235527447341995, 0.00002345052687215618], [0.99919829885432287497, 0.00077216368141466826, 0.00002953746426263702]];

  ind = 0;
  assert(genoprobs.length == genoprobs_from_rqtl.length);
  foreach(i; 0..genoprobs.length) {
    assert(genoprobs[i][ind].length == genoprobs_from_rqtl[i].length);
    foreach(j; 0..1) {
      assert(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]) < 1e-10,
             to!string(i) ~ "  " ~
             to!string(genoprobs[i][ind][j]) ~ "  " ~
             to!string(genoprobs_from_rqtl[i][j]) ~ "  " ~
             to!string(log10(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]))));
    }
  }
  
  // probs from R/qtl for ind'l 27
  genoprobs_from_rqtl = [[0.00001706063466553371, 0.99996359264873346806, 0.00001934671660100166], [0.00000542729907139706, 0.99998425590939321594, 0.00001031679153513373], [0.00167431980159984365, 0.99498883477563293543, 0.00333684542276671764], [0.00300430267305644731, 0.99067066427994321387, 0.00632503304700018140], [0.00399804643092083623, 0.98702383624113243510, 0.00897811732794714240], [0.00465776212837853195, 0.98404336101813516535, 0.01129887685348606070], [0.00498520467071393927, 0.98172516068311965753, 0.01328963464616587757], [0.00498167550789427403, 0.98006606344200652980, 0.01495226105009991521], [0.00464802470712830876, 0.97906379929477149737, 0.01628817599810009412], [0.00398465240833526489, 0.97871699692961144912, 0.01729835066205359650], [0.00299150966461544845, 0.97902518184668385626, 0.01798330848870059381], [0.00166809866897262341, 0.97998877570889908473, 0.01834312562212889880], [0.00001347236769887946, 0.98160909691883757588, 0.01837743071346389576], [0.00011263177102181188, 0.65436580946881661713, 0.34552155876016116265], [0.00005487815236952483, 0.32732377584639010815, 0.67262134600124012795], [0.00000008945179434168, 0.00005661626397888805, 0.99994329428422679129], [0.00000008945354484454, 0.00005478964492995142, 0.99994512090152476436], [0.00000032118183143107, 0.00101791385226538138, 0.99898176496590362916], [0.00000067538225346972, 0.00159240460307560243, 0.99840692001467068462], [0.00000081711944192661, 0.00177915539661966629, 0.99822002748393812155], [0.00000063752566405884, 0.00157845668438947500, 0.99842090578994657779], [0.00000025358909081293, 0.00098999632184585762, 0.99900975008906323094], [0.00000000838133904767, 0.00001285908294353619, 0.99998713253571780424], [0.00000001534477949811, 0.00021081985160242796, 0.99978916480361812447], [0.00000001363661676841, 0.00020935822761357633, 0.99979062813577035396], [0.00000000369389026148, 0.00000847304464930174, 0.99999152326145956948], [0.00000008558029292317, 0.00057750414441595701, 0.99942241027529099551], [0.00000014826103009595, 0.00076653150621263104, 0.99923332023275723834], [0.00000008392643814716, 0.00057584267692486308, 0.99942407339663685839], [0.00000000133336090595, 0.00000514758225627987, 0.99999485108438224135], [0.00000000238242727110, 0.00008757626840377222, 0.99991242134916868967], [0.00000000045998229883, 0.00000298163372753310, 0.99999701790629047515], [0.00000001309583730291, 0.00022691236328265449, 0.99977307454087993577], [0.00000001288496149169, 0.00022595095622626409, 0.99977403615881199617], [0.00000000015176176266, 0.00000009654736301179, 0.99999990330087418222], [0.00000000015188037252, 0.00000010254174979134, 0.99999989730636762442], [0.00000093585296563868, 0.00138429973780618992, 0.99861476440922791742], [0.00000326867351546000, 0.00239895406704874288, 0.99759777725943576954], [0.00000644044241062990, 0.00304555622483396833, 0.99694800333275579440], [0.00001009607645979595, 0.00332505617688550175, 0.99666484774665442536], [0.00001408292660500108, 0.00323786455495118615, 0.99674805251844411647], [0.00001845049562093424, 0.00278385326008914443, 0.99719769624428966637], [0.00002345052687183109, 0.00196235527446920891, 0.99801419419865911031], [0.00002953746426230961, 0.00077216368141321294, 0.99919829885432465133]];
  ind = 26;
  assert(genoprobs.length == genoprobs_from_rqtl.length);
  foreach(i; 0..genoprobs.length) {
    assert(genoprobs[i][ind].length == genoprobs_from_rqtl[i].length);
    foreach(j; 0..1) {
      assert(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]) < 1e-10,
             to!string(i) ~ "  " ~
             to!string(genoprobs[i][ind][j]) ~ "  " ~
             to!string(genoprobs_from_rqtl[i][j]) ~ "  " ~
             to!string(log10(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]))));
    }
  }
  
  // probs from R/qtl for ind'l 120
  genoprobs_from_rqtl = [[0.00003389923748556352, 0.99659312663270072097, 0.00337297412981356608], [0.00000801711540126647, 0.99948197331100663288, 0.00051000957359357223], [0.00169906069207385337, 0.99614587613805960498, 0.00215506316986592257], [0.00305060942768221356, 0.99348861268333943375, 0.00346077788897814669], [0.00406448901288740394, 0.99150654724186593203, 0.00442896374524633790], [0.00474206320668295756, 0.99019696792401612484, 0.00506096886930077535], [0.00508423569429013438, 0.98955808294507385803, 0.00535768136063597290], [0.00509145131559570266, 0.98958901817368594145, 0.00531953051071768108], [0.00476369666581028407, 0.99028981593586640209, 0.00494648739832338844], [0.00410050006916634190, 0.99166143507290094306, 0.00423806485793321204], [0.00310093092561705697, 0.99370575225325252777, 0.00319331682113098815], [0.00176359842963963909, 0.99642556454024300283, 0.00181083703011698121], [0.00008664965938729717, 0.99982459321903727201, 0.00008875712157480426], [0.00145817276314296937, 0.99708176916663004974, 0.00146005807022706199], [0.00250566134181485134, 0.99498701354994911750, 0.00250732510823592405], [0.00323048094627445591, 0.99353759533945518179, 0.00323192371427058825], [0.00323110540854978662, 0.99353634665946966020, 0.00323254793198096647], [0.00365480154485681944, 0.99268919522739251793, 0.00365600322775114662], [0.00369536035592773040, 0.99260831797859161441, 0.00369632166548090196], [0.00335284478224494179, 0.99329358912555554273, 0.00335356609219922448], [0.00262672197305625433, 0.99474607446309881720, 0.00262720356384578456], [0.00151586245758338826, 0.99696803302597425400, 0.00151610451644320927], [0.00001853838831395025, 0.99996292060233327170, 0.00001854100935279364], [0.00021451648394345767, 0.99957096527700384225, 0.00021451823905302008], [0.00021117401222328137, 0.99957765108602236737, 0.00021117490175367508], [0.00000850830571234144, 0.99998298336444824130, 0.00000850832984101149], [0.00057665418936913529, 0.99884669160316319481, 0.00057665420746776097], [0.00076537930777502981, 0.99846924137237402785, 0.00076537931985049218], [0.00057497074804194193, 0.99885005849785890586, 0.00057497075409883216], [0.00000513886221383076, 0.99998972227553140080, 0.00000513886225445101], [0.00008755536404365867, 0.99982488927189328010, 0.00008755536406414409], [0.00000297950103348627, 0.99999404099793309797, 0.00000297950103384004], [0.00022679493039349830, 0.99954641013921241566, 0.00022679493039373360], [0.00022583292150520363, 0.99954833415698840504, 0.00022583292150532157], [0.00000009260863165112, 0.99999981478273824997, 0.00000009260863165115], [0.00000009826277582890, 0.99999980347444794582, 0.00000009826277582893], [0.00132162994166935550, 0.99735674011666097805, 0.00132162994166935550], [0.00227781188437427761, 0.99544437623125237025, 0.00227781188437427545], [0.00287004888062133024, 0.99425990223875770901, 0.00287004888062132764], [0.00309921102470255309, 0.99380157795059442805, 0.00309921102470255309], [0.00296563499378398781, 0.99406873001243212240, 0.00296563499378398260], [0.00246912454254019642, 0.99506175091491966267, 0.00246912454254019642], [0.00160895021483740703, 0.99678209957032515298, 0.00160895021483740703], [0.00038384827204154993, 0.99923230345591729229, 0.00038384827204154993]];
  ind = 119;
  assert(genoprobs.length == genoprobs_from_rqtl.length);
  foreach(i; 0..genoprobs.length) {
    assert(genoprobs[i][ind].length == genoprobs_from_rqtl[i].length);
    foreach(j; 0..1) {
      assert(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]) < 1e-10,
             to!string(i) ~ "  " ~
             to!string(genoprobs[i][ind][j]) ~ "  " ~
             to!string(genoprobs_from_rqtl[i][j]) ~ "  " ~
             to!string(log10(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]))));
    }
  }
  

  // test calc_geno_prob with listeria data, chr 19
  writeln("Test calc_geno_prob with listeria data, chr 19");
  auto chr19_map = markers_by_chr_sorted[18][1];
  auto pmap_stepped_chr19 = add_stepped_markers_autosome(chr19_map, 1.0, 0.0);
  rec_frac = recombination_fractions(pmap_stepped_chr19, GeneticMapFunc.Carter_Falconer);

  genoprobs = calc_geno_prob_F2(genotype_matrix, pmap_stepped_chr19, rec_frac, 0.001);

  /******************************
   * in R:

   data(listeria)
   for(i in seq(along=listeria$geno)) {
     m <- listeria$geno[[i]]$map
     listeria$geno[[i]]$map <- round(m, ifelse(m < 10, 5, 4))
   }
   listeria <- calc.genoprob(listeria, err=0.001, map="c-f", step=1)
   for(ind in c(1, 27, 120))
     print(paste0("genoprobs_from_rqtl = [",
                  paste(apply(listeria$geno[["19"]]$prob[ind,,], 1, function(a) paste0("[", paste(sprintf("%.20f", a), collapse=", "), "]")), collapse=", "),
                  "];"))

   *
   ******************************/

  // probs from R/qtl for ind'l 1
  genoprobs_from_rqtl = [[0.00007985688594897228, 0.99984028617910125636, 0.00007985693494935986], [0.00309506433484527804, 0.99380986930326298268, 0.00309506636189124749], [0.00570712057830845710, 0.98858575483746391477, 0.00570712458422738267], [0.00792029063405797797, 0.98415941274545726269, 0.00792029662048491546], [0.00973818821064758797, 0.98052361560932632667, 0.00973819618002597781], [0.01116378160799983213, 0.97767242682841715151, 0.01116379156358248727], [0.01219939856410467462, 0.97560119092593988732, 0.01219941050995508418], [0.01284673005579609756, 0.97430652594741395944, 0.01284674399679014943], [0.01310683305981266700, 0.97378631793854697474, 0.01310684900164054041], [0.01298013227865027139, 0.97403971749353113196, 0.01298015022781884298], [0.01246642083402523145, 0.97506713836811431673, 0.01246644079786068428], [0.01156485992907981680, 0.97687025815518979677, 0.01156488191573065358], [0.01027397747877887083, 0.97945202102400186206, 0.01027400149721924803], [0.00859166570626111910, 0.98281664252744405097, 0.00859169176629446391], [0.00651517770122035569, 0.98696961648529624167, 0.00651520581348343127], [0.00404112293469711687, 0.99191772395463861933, 0.00404115311066430890], [0.00116546172295720995, 0.99766904430209668586, 0.00116549397494523270], [0.00002565445937128223, 0.99994865807524779822, 0.00002568746538197370], [0.00199691677597619872, 0.99600349077507954743, 0.00199959244894413980], [0.00477757276033847524, 0.99043800724551855907, 0.00478441999414322503], [0.00715782896343562097, 0.98567332048369815656, 0.00716885055286629880], [0.00914157447021257327, 0.98170165061591019295, 0.00915677491387682091], [0.01073205093795100672, 0.97851651262193872771, 0.01075143644011115028], [0.01193185789035507670, 0.97611270574618469453, 0.01195543636346044561], [0.01274295696315062669, 0.97448630500578226066, 0.01277073803106717684], [0.01316667510813022621, 0.97363465478180166723, 0.01319867011006863912], [0.01320370676087640437, 0.97355636448310323150, 0.01323992875602027566], [0.01285411497570280136, 0.97425130627575817766, 0.01289457874853898629], [0.01211733152966697202, 0.97572061487431360760, 0.01216205359602006396], [0.01099215599582490689, 0.97796668939457664926, 0.01104115460959836058], [0.00947675378421487455, 0.98099319727094358434, 0.00953004894484159835], [0.00756865314737178736, 0.98480508024465085448, 0.00762626660797716301], [0.00526474114548347496, 0.98940856243275276949, 0.00532669642176418403], [0.00256125856460096913, 0.99481116049097573217, 0.00262758094442324362], [0.00001769779733962415, 0.99989464625498236661, 0.00008765594767863333], [0.00038833732318512563, 0.99766408356325508855, 0.00194757911355950041], [0.00234161290541819644, 0.98495863762378854656, 0.01269974947079359311], [0.00389684960942390194, 0.97304504163020577590, 0.02305810876037012874], [0.00506197725593077619, 0.96190384283002439147, 0.03303417991404490606], [0.00584429347694099145, 0.95151684965599969690, 0.04263885686705991968], [0.00625047783356429652, 0.94186710202257872826, 0.05188242014385630041], [0.00628660492750730653, 0.93293884363314893982, 0.06077455143934452214], [0.00595815652852659580, 0.92471749625283317098, 0.06932434721863989235], [0.00527003273854935537, 0.91718963590488111759, 0.07754033135656965281], [0.00422656221159377690, 0.91034297095172289627, 0.08543046683668345520], [0.00283151144708228752, 0.90416632202495106352, 0.09300216652796691741], [0.00108809317263019404, 0.89864960377142555359, 0.10026230305594403813], [0.00010377221271818312, 0.89617590117545808948, 0.10372032661182394031]];

  ind = 0;
  assert(genoprobs.length == genoprobs_from_rqtl.length);
  foreach(i; 0..genoprobs.length) {
    assert(genoprobs[i][ind].length == genoprobs_from_rqtl[i].length);
    foreach(j; 0..1) {
      assert(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]) < 1e-10,
             to!string(i) ~ "  " ~
             to!string(genoprobs[i][ind][j]) ~ "  " ~
             to!string(genoprobs_from_rqtl[i][j]) ~ "  " ~
             to!string(log10(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]))));
    }
  }
  
  // probs from R/qtl for ind'l 27
  genoprobs_from_rqtl = [[0.00007982113970065615, 0.99983965943298969137, 0.00008051942730967115], [0.00309358836227369453, 0.99378393654305474669, 0.00312247509467102622], [0.00570421965633514071, 0.98853447371964187074, 0.00576130662402303800], [0.00791599497950557646, 0.98408269953720906020, 0.00800130548328567212], [0.00973254304384524489, 0.98042134505182565452, 0.00984611190432908324], [0.01115684724793996468, 0.97754443193229856313, 0.01129872081976147045], [0.01219125055531529445, 0.97544726269863346602, 0.01236148674605105219], [0.01283745932714727006, 0.97412641305190039720, 0.01303612762095230845], [0.01309654611553114946, 0.97357972628296918227, 0.01332372760149970990], [0.01296895142187126822, 0.97380630975099413682, 0.01322473882713451170], [0.01245448442326684176, 0.97480653342589274057, 0.01273898215084056512], [0.01155232266808195983, 0.97658203049243841321, 0.01186564683948010054], [0.01026101074020601377, 0.97913570001695671152, 0.01060328924283721226], [0.00857845788982649834, 0.98247171168098079708, 0.00894983042919302030], [0.00650193462684835709, 0.98659551258958311237, 0.00690255278356871876], [0.00402806827140060001, 0.99151383616552013489, 0.00445809556307922693], [0.00115283745416807563, 0.99723471314369516172, 0.00161244940213715730], [0.00001324906528099612, 0.99950314460473521638, 0.00048360632998410122], [0.00099277486973804794, 0.95988435843565089733, 0.03912286669461199906], [0.00222943738684370802, 0.89796355993727416944, 0.09980700267588185626], [0.00312128477538778804, 0.83669256412092640751, 0.16018615110368533694], [0.00370619901063546330, 0.77597132650660871622, 0.22032247448275563140], [0.00402160015659525170, 0.71570070027026566617, 0.28027769957313952709], [0.00410452234990563505, 0.65578227435490810127, 0.34011320329518601735], [0.00399168917566933897, 0.59611821278312093764, 0.39989009804120950742], [0.00371958856439451747, 0.53661109490856173654, 0.45966931652704406952], [0.00332454733843149958, 0.47716375634562285812, 0.51951169631594518172], [0.00284280553573541860, 0.41767913031752956776, 0.57947806414673497244], [0.00231059063843799687, 0.35806008916380283047, 0.63962932019775908810], [0.00176419183357534766, 0.29820928574831856439, 0.70002652241810592315], [0.00124003443339253897, 0.23802899450900003031, 0.76073097105760756342], [0.00077475458293033270, 0.17742095188960935181, 0.82180429352746031668], [0.00040527438309510296, 0.11628619589309154014, 0.88330852972381335153], [0.00016887755812040550, 0.05452490449449045457, 0.94530621794738922681], [0.00010075332123046163, 0.00284904240074571090, 0.99705020427802304450], [0.00010082803540370832, 0.00596142434981001765, 0.99393774761478592694], [0.00012177162091641632, 0.02407086934020438371, 0.97580735903887927396], [0.00016981668151678204, 0.04172787239088514982, 0.95810231092759823301], [0.00023417094729600167, 0.05896126420167991516, 0.94080456485102426090], [0.00030430819425308935, 0.07579918379170108578, 0.92389650801404554770], [0.00036994671756348304, 0.09226912444528637125, 0.90736092883715002699], [0.00042102830005297210, 0.10839797860357058834, 0.89118099309637632821], [0.00044769763980428111, 0.12421208177499035163, 0.87534022058520521981], [0.00044028220161177129, 0.13973725553641630492, 0.85982246226197189820], [0.00038927245772956933, 0.15499884969512889299, 0.84461187784714153448], [0.00028530248403114977, 0.17002178368047998758, 0.82969291383548893215], [0.00011913087831515256, 0.18483058723282314029, 0.81505028188886197160], [0.00001180873179606715, 0.19204202457343882982, 0.80794616669476471138]];
  ind = 26;
  assert(genoprobs.length == genoprobs_from_rqtl.length);
  foreach(i; 0..genoprobs.length) {
    assert(genoprobs[i][ind].length == genoprobs_from_rqtl[i].length);
    foreach(j; 0..1) {
      assert(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]) < 1e-10,
             to!string(i) ~ "  " ~
             to!string(genoprobs[i][ind][j]) ~ "  " ~
             to!string(genoprobs_from_rqtl[i][j]) ~ "  " ~
             to!string(log10(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]))));
    }
  }

  // probs from R/qtl for ind'l 120
  genoprobs_from_rqtl = [[0.24999999999999988898, 0.50000000000000011102, 0.25000000000000011102], [0.24999999999999977796, 0.50000000000000022204, 0.25000000000000000000], [0.24999999999999977796, 0.50000000000000033307, 0.24999999999999994449], [0.24999999999999972244, 0.50000000000000033307, 0.24999999999999994449], [0.24999999999999972244, 0.50000000000000033307, 0.24999999999999994449], [0.24999999999999961142, 0.50000000000000033307, 0.24999999999999994449], [0.24999999999999961142, 0.50000000000000044409, 0.25000000000000000000], [0.24999999999999955591, 0.50000000000000044409, 0.25000000000000000000], [0.24999999999999950040, 0.50000000000000044409, 0.25000000000000000000], [0.24999999999999955591, 0.50000000000000044409, 0.25000000000000000000], [0.24999999999999955591, 0.50000000000000044409, 0.25000000000000000000], [0.24999999999999955591, 0.50000000000000044409, 0.25000000000000000000], [0.24999999999999955591, 0.50000000000000044409, 0.25000000000000000000], [0.24999999999999955591, 0.50000000000000044409, 0.25000000000000000000], [0.24999999999999955591, 0.50000000000000044409, 0.25000000000000000000], [0.24999999999999955591, 0.50000000000000044409, 0.25000000000000000000], [0.24999999999999961142, 0.50000000000000033307, 0.25000000000000005551], [0.24999999999999966693, 0.50000000000000055511, 0.24999999999999994449], [0.24999999999999972244, 0.50000000000000033307, 0.24999999999999994449], [0.24999999999999961142, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999961142, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999961142, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999961142, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999961142, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999966693, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999966693, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999966693, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999966693, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999966693, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999966693, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999966693, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999972244, 0.50000000000000044409, 0.24999999999999983347], [0.24999999999999972244, 0.50000000000000044409, 0.24999999999999983347], [0.24999999999999972244, 0.50000000000000055511, 0.24999999999999983347], [0.24999999999999966693, 0.50000000000000066613, 0.24999999999999966693], [0.24999999999999972244, 0.50000000000000066613, 0.24999999999999972244], [0.24999999999999972244, 0.50000000000000055511, 0.24999999999999961142], [0.24999999999999972244, 0.50000000000000055511, 0.24999999999999961142], [0.24999999999999972244, 0.50000000000000055511, 0.24999999999999961142], [0.24999999999999972244, 0.50000000000000055511, 0.24999999999999961142], [0.24999999999999972244, 0.50000000000000055511, 0.24999999999999961142], [0.24999999999999972244, 0.50000000000000055511, 0.24999999999999961142], [0.24999999999999972244, 0.50000000000000055511, 0.24999999999999961142], [0.24999999999999983347, 0.50000000000000055511, 0.24999999999999961142], [0.24999999999999983347, 0.50000000000000055511, 0.24999999999999961142], [0.24999999999999983347, 0.50000000000000055511, 0.24999999999999961142], [0.24999999999999977796, 0.50000000000000066613, 0.24999999999999961142], [0.24999999999999983347, 0.50000000000000055511, 0.24999999999999977796]];
  ind = 119;
  assert(genoprobs.length == genoprobs_from_rqtl.length);
  foreach(i; 0..genoprobs.length) {
    assert(genoprobs[i][ind].length == genoprobs_from_rqtl[i].length);
    foreach(j; 0..1) {
      assert(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]) < 1e-10,
             to!string(i) ~ "  " ~
             to!string(genoprobs[i][ind][j]) ~ "  " ~
             to!string(genoprobs_from_rqtl[i][j]) ~ "  " ~
             to!string(log10(abs(genoprobs[i][ind][j] - genoprobs_from_rqtl[i][j]))));
    }
  }

  // test estmap with listeria data, chr 13
  writeln("Test estmap with listeria data, chr 13");

  chr13_map = markers_by_chr_sorted[12][1];
  rec_frac = recombination_fractions(chr13_map, GeneticMapFunc.Kosambi);
  auto rec_frac_rev = estmap_F2(genotype_matrix, chr13_map, rec_frac, 0.002, 100, 1e-6, false);

  /******************************
   * in R:

   data(listeria)
   for(i in seq(along=listeria$geno)) {
     m <- listeria$geno[[i]]$map
     listeria$geno[[i]]$map <- round(m, ifelse(m < 10, 5, 4))
   }
   listeria <- listeria["13",]
   rf <- mf.k(diff(unlist(pull.map(listeria))))
   map <- est.map(listeria, err=0.002, map.function="haldane", tol=1e-7)
   rfrev <- mf.h(diff(unlist(map)))
   paste0("auto rec_frac_rqtl = [", paste(sprintf("%.20f", rf), collapse=", "), "];")
   paste0("auto rec_frac_rev_rqtl = [", paste(sprintf("%.20f", rfrev), collapse=", "), "];")

   *
   ******************************/

  auto rec_frac_rqtl = [0.00286746856284019434, 0.09944808740648146406, 0.02681325235664829693, 0.00000999999999867889, 0.05831343140397290958, 0.02102559363219945812, 0.03855033870325273726, 0.01283917692671171160, 0.02231716200601452718, 0.00000999999999864336, 0.07535555806962258851];
  auto rec_frac_rev_rqtl = [0.01183048207281117703, 0.10662947366989505849, 0.03230106006563365773, 0.00000000010000000827, 0.05675828936512006262, 0.02110557519841715912, 0.03833376626430756717, 0.01427505015825597523, 0.02370366835248577386, 0.00000000010000000827, 0.08059502076315694374];

  assert(rec_frac_rqtl.length == rec_frac.length);
  foreach(i; 0..rec_frac.length) {
    assert(abs(rec_frac[i] - rec_frac_rqtl[i]) < 1e-10);
  }

  assert(rec_frac_rev_rqtl.length == rec_frac_rev.length);
  foreach(i; 0..rec_frac_rev.length) {
    assert(abs(rec_frac_rev[i] - rec_frac_rev_rqtl[i]) < 1e-7);
  }

  // test estmap with listeria data, chr 7
  writeln("Test estmap with listeria data, chr 7");

  auto chr7_map = markers_by_chr_sorted[6][1];
  rec_frac = recombination_fractions(chr7_map, GeneticMapFunc.Haldane);
  rec_frac_rev = estmap_F2(genotype_matrix, chr7_map, rec_frac, 0.01, 100, 1e-6, false);

  /******************************
   * in R:

   data(listeria)
   for(i in seq(along=listeria$geno)) {
     m <- listeria$geno[[i]]$map
     listeria$geno[[i]]$map <- round(m, ifelse(m < 10, 5, 4))
   }
   listeria <- listeria["7",] # pull out chr 7
   rf <- mf.h(diff(unlist(pull.map(listeria))))
   map <- est.map(listeria, err=0.01, map.function="kosambi", tol=1e-7)
   rfrev <- mf.k(diff(unlist(map)))
   paste0("rec_frac_rqtl = [", paste(sprintf("%.20f", rf), collapse=", "), "];")
   paste0("rec_frac_rev_rqtl = [", paste(sprintf("%.20f", rfrev), collapse=", "), "];")

   *
   ******************************/

  rec_frac_rqtl = [0.15661986512953757211, 0.13781102774534148558, 0.05760192522590779074, 0.15864052585018517672, 0.10645079739692664411];
  rec_frac_rev_rqtl = [0.17951889354759650863, 0.15585635626654303909, 0.06089437521095571182, 0.18207986319588378987, 0.11747108802069636257];

  assert(rec_frac_rqtl.length == rec_frac.length);
  foreach(i; 0..rec_frac.length) {
    assert(abs(rec_frac[i] - rec_frac_rqtl[i]) < 1e-10);
  }

  assert(rec_frac_rev_rqtl.length == rec_frac_rev.length);
  foreach(i; 0..rec_frac_rev.length) {
    assert(abs(rec_frac_rev[i] - rec_frac_rev_rqtl[i]) < 1e-7);
  }
}
