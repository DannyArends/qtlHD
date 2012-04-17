/**
 * calc_genoprob
 */

module qtl.core.hmm.calcgenoprob;

import std.string;
import std.conv;
import std.stdio;
import std.math;
import qtl.core.primitives, qtl.core.genotype;
import qtl.core.hmm.util;
import qtl.core.hmm.forwardbackward;

// calculate QTL genotype probabilities
double[][][] calc_geno_prob(alias init, alias emit, alias step)(in GenotypeCombinator[][] genotypes,
                                                                in TrueGenotype[] all_true_geno,
                                                                in Marker[] marker_map,
                                                                in double[] rec_frac,
                                                                in double error_prob)
{
  if(marker_map.length != rec_frac.length+1) {
    throw new Exception("no. positions in marker map doesn't match rec_frac length");
  }
  if(error_prob < 0.0 || error_prob > 1.0)
    throw new Exception("error_prob out of range");
  foreach(rf; rec_frac) {
    if(rf < 0 || rf > 0.5)
      throw new Exception("rec_frac must be >= 0 and <= 0.5");
  }

  size_t n_individuals = genotypes.length;
  size_t n_positions = marker_map.length;

  auto alpha = new double[][](all_true_geno.length,n_positions);
  auto beta = new double[][](all_true_geno.length,n_positions);
  auto genoprobs = new double[][][](n_positions,n_individuals,all_true_geno.length);

  foreach(ind; 0..n_individuals) {
    alpha = forwardEquations!(init, emit, step)(genotypes[ind], all_true_geno, marker_map, rec_frac, error_prob);
    beta = backwardEquations!(init, emit, step)(genotypes[ind], all_true_geno, marker_map, rec_frac, error_prob);

    // calculate genotype probabilities
    double sum_at_pos;
    foreach(pos; 0..n_positions) {
      sum_at_pos = genoprobs[pos][ind][0] = alpha[0][pos] + beta[0][pos];
      foreach(i; 1 .. all_true_geno.length) {
        auto true_geno = all_true_geno[i];
        genoprobs[pos][ind][i] = alpha[i][pos] + beta[i][pos];
        sum_at_pos = addlog(sum_at_pos, genoprobs[pos][ind][i]);
      }
      foreach(i, true_geno; all_true_geno) {
        genoprobs[pos][ind][i] = exp(genoprobs[pos][ind][i] - sum_at_pos);
      }
    }
  }
  return genoprobs;
}