/*
 * regression: linear regression utility functions
 **/

module qtl.core.scanone.regression;

import std.algorithm;
import std.range;
import std.c.stdio;
import std.stdio;
import std.string;

extern(C) {
  alias float f_float;
  alias double f_double;
  alias int f_int;
}

version(Windows){
  private import std.loader;
  private import qtl.core.util.windows;
  private import qtl.plugins.renv.libload;

  extern (C) void function(f_double *x, f_int *n, f_int *p, f_double *y, f_int *ny,
                           f_double *tol, f_double *b, f_double *rsd, f_double *qty,
                           f_int *k, f_int *jpvt, f_double *qraux, f_double *work) dqrls_;

  static this(){
    HXModule lib = load_library("Rblas");
    load_function(dqrls_)(lib,"dqrls_");
    writeln("Loaded BLAS functionality");
  }

}else{
  pragma(lib, "blas");
  pragma(lib, "lapack");

  // The C interface from the SciD library:
  extern (C) void dqrls_(f_double *x, f_int *n, f_int *p, f_double *y, f_int *ny,
                         f_double *tol, f_double *b, f_double *rsd, f_double *qty,
                         f_int *k, f_int *jpvt, f_double *qraux, f_double *work);
}

// The D interface is a D-ified call which calls the C interface dqrls_
void qrls(f_double *x,     // [n x p] covariate matrix
          f_int n,         // number of individuals
          f_int p,         // number of covariates
          f_double *y,     // [n x ny] outcome matrix
          f_int ny,        // number of outcomes
          f_double tol,    //
          f_double *b,     // [p x ny] matrix
          f_double *rsd,   // [n x ny] matrix
          f_double *qty,   // [n x ny] matrix
          f_int k,         //
          f_int *jpvt,     // [p] vector of pivots
          f_double *qraux, // [p] vector
          f_double *work)  // [p] vector
{
  // see R-2.15.0/src/appl/dqrls.f
  dqrls(x, &n, &p, y, &ny, &tol, b, rsd, qty, &k, jpvt, qraux, work);
}



// x matrix
//         8    9    5
//         5    2    1
//         4    2    8
//         3    2    1
//         3    9    4
//
// y =     42   12   32   10   33  
//
// resid =  0.42328 73370 96660 221114
//         -0.33645 20175 62198 779643
//         -0.05099 65851 27883 312105
//         -0.20935 25681 23212 373630
//         -0.29066 48546 93705 954070



// not full rank x matrix
//         8    9   11    5    6
//         5    2    9    1    5
//         4    2    0    8    3
//         3    2    5    1    2
//         3    9    2    4    1
//
// resid =  0.42323 74179 03404 522512
//         -0.33310 35233 49901 564643
//         -0.05094 52447 47632 054128
//         -0.21553 75739 32289 283629
//         -0.28999 60085 63443 874451