/**
 * hmm_forwardbackward
 */

module qtl.core.hmm.hmm_forwardbackward;

import std.stdio;
import std.math;

import qtl.core.map.genetic_map_functions;
import qtl.core.primitives, qtl.core.genotype;
import qtl.core.hmm.hmm_util;

// forward Equations
double[][] forwardEquations(alias init, alias emit, alias step)(GenotypeCombinator[] genotypes,
                                                                TrueGenotype[] all_true_geno,
                                                                Marker[] marker_map,
                                                                double[] rec_frac,
                                                                double error_prob)
{
  size_t n_positions = marker_map.length;

  auto alpha = new double[][](all_true_geno.length, n_positions);

  writefln("total markers = %d    no. pos = %d", genotypes.length, marker_map.length);

  // initialize alphas
  writef("%2d %10s  ", 0, genotypes[marker_map[0].id]);
  foreach(tg_index, true_geno; all_true_geno) {
    if(isPseudoMarker(marker_map[0]))
      alpha[tg_index][0] = init(true_geno);
    else
      alpha[tg_index][0] = init(true_geno) + emit(genotypes[marker_map[0].id], true_geno, error_prob);
    writef("%9.5f ", alpha[tg_index][0]);
    writef("[%9.5f %9.5f] ", init(true_geno), emit(genotypes[marker_map[0].id], true_geno, error_prob));
  }
  writeln();

  foreach(pos; 1 .. n_positions) {
    writef("%2d %10s ", pos, genotypes[marker_map[pos].id]);
    foreach(tgr_index, true_geno_right; all_true_geno) {

     alpha[tgr_index][pos] = alpha[0][pos-1] +
       step(all_true_geno[0], true_geno_right, rec_frac[pos-1]);

     foreach(tgl_index, true_geno_left; all_true_geno[1..$]) {
       alpha[tgr_index][pos] = addlog(alpha[tgr_index][pos],
                                        alpha[tgl_index][pos-1] +
                                        step(true_geno_left, true_geno_right, rec_frac[pos-1]));
     }
     if(!isPseudoMarker(marker_map[pos]))
       alpha[tgr_index][pos] += emit(genotypes[marker_map[pos].id], true_geno_right, error_prob);
     writef("%9.5f ", alpha[tgr_index][pos]);
    writef("[%9.5f] ", emit(genotypes[marker_map[pos].id], true_geno_right, error_prob));
    }
    writeln();
  }
  return alpha;
}



// backward Equations
double[][] backwardEquations(alias init, alias emit, alias step)(GenotypeCombinator[] genotypes,
                                                                 TrueGenotype[] all_true_geno,
                                                                 Marker[] marker_map,
                                                                 double[] rec_frac,
                                                                 double error_prob)
{
  size_t n_positions = marker_map.length;

  auto beta = new double[][](all_true_geno.length,n_positions);

  // initialize beta
  foreach(tg_index, true_geno; all_true_geno) {
    beta[tg_index][n_positions-1] = 0.0;
  }

  // backward equations
  for(int pos = cast(int)n_positions-2; pos >= 0; pos--) {
    foreach(tgl_index, true_geno_left; all_true_geno) {
      if(isPseudoMarker(marker_map[pos+1]))
        beta[tgl_index][pos] = beta[0][pos+1] +
          step(true_geno_left, all_true_geno[0], rec_frac[pos]);
      else
        beta[tgl_index][pos] = beta[0][pos+1] +
          step(true_geno_left, all_true_geno[0], rec_frac[pos]) +
          emit(genotypes[marker_map[pos+1].id], all_true_geno[0], error_prob);

      foreach(tgr_index, true_geno_right; all_true_geno[1..$]) {
        if(isPseudoMarker(marker_map[pos+1]))
          beta[tgl_index][pos] = addlog(beta[tgl_index][pos],
                                        beta[tgr_index][pos+1] +
                                        step(true_geno_left, true_geno_right, rec_frac[pos]));
       else
         beta[tgl_index][pos] = addlog(beta[tgl_index][pos],
                                       beta[tgr_index][pos+1] +
                                       step(true_geno_left, true_geno_right, rec_frac[pos])+
                                       emit(genotypes[marker_map[pos+1].id], true_geno_right, error_prob));
     }
    }
  }

  return beta;
}
