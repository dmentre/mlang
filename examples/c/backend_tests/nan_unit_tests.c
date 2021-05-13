/* DISCLAIMER: this NaN code is probably buggy. The code below is not
   well designed, without guarantee of covering correctly the different
   cases. The testing work was never finished. Use at your own risk.
 */

#include <stdio.h>
#include "m_value.h"
#include "m_nan_value.h"

#define N 5

m_value x_m_value[N] = {
  { 0.0, true}, // m_undefined
  { 0.0, true}, // m_undefined
  { 0.0, true}, // m_undefined
  { 1.6, false },
  { 0.0, false },
};

m_value y_m_value[N] = {
  { 0.0, true}, // m_undefined
  { 1.0, false },
  { 0.0, false },
  { 1.0, false },
  { 1.0, false },
};

m_nan_value x_m_nan_value[N] = {
  NAN, // m_nan_undefined
  NAN, // m_nan_undefined
  NAN, // m_nan_undefined
  1.6,
  0.0,
};

m_nan_value y_m_nan_value[N] = {
  NAN, // m_nan_undefined
  1.0,
  0.0,
  1.0,
  1.0,
};

int compare_nan_vs_m_value(const m_value v, const m_nan_value nan_v, int line)
{
  if (v.undefined && M_NAN_UNDEFINED(nan_v))
    return 0;

  if (!v.undefined && !M_NAN_UNDEFINED(nan_v) && v.value == nan_v)
    return 0;

  printf("ERROR: line:%d m_value(%f,%s) != m_nan_value(%f)\n",
         line, v.value, v.undefined ? "UNDEF" : "DEF", nan_v);

  return 1;
}

int compare_binary_op(m_value (*m_op)(m_value x, m_value y),
                   m_nan_value (*m_nan_op)(m_nan_value x, m_nan_value y),
                   int line)
{
  int err = 0;
  int i;
  m_value r_m_value;
  m_nan_value r_m_nan_value;

  for (i=0; i<N; i++) {
    r_m_value = (*m_op)(x_m_value[i], y_m_value[i]);
    r_m_nan_value = (*m_nan_op)(x_m_nan_value[i], y_m_nan_value[i]);
    err += compare_nan_vs_m_value(r_m_value, r_m_nan_value, line);
  }

  return err;
}

int compare_unary_op(m_value (*m_op)(m_value x),
                     m_nan_value (*m_nan_op)(m_nan_value x),
                     int line)
{
  int err = 0;
  int i;
  m_value r_m_value;
  m_nan_value r_m_nan_value;

  for (i=0; i<N; i++) {
    r_m_value = (*m_op)(x_m_value[i]);
    r_m_nan_value = (*m_nan_op)(x_m_nan_value[i]);
    err += compare_nan_vs_m_value(r_m_value, r_m_nan_value, line);
  }

  return err;
}

int compare_operators(void)
{
  int err = 0;
  int i;

  for (i=0; i<N; i++) {
    err += compare_nan_vs_m_value(x_m_value[i], x_m_nan_value[i], __LINE__);
  }

  err += compare_binary_op(m_add, m_nan_add, __LINE__);
  err += compare_binary_op(m_sub, m_nan_sub, __LINE__);
  err += compare_unary_op(m_neg, m_nan_neg, __LINE__);
  err += compare_binary_op(m_mul, m_nan_mul, __LINE__);
  err += compare_binary_op(m_div, m_nan_div, __LINE__); // TODO: error!
  err += compare_binary_op(m_lt, m_nan_lt, __LINE__);
  err += compare_binary_op(m_lte, m_nan_lte, __LINE__);
  err += compare_binary_op(m_gt, m_nan_gt, __LINE__);
  err += compare_binary_op(m_gte, m_nan_gte, __LINE__);
  err += compare_binary_op(m_eq, m_nan_eq, __LINE__);
  err += compare_binary_op(m_neq, m_nan_neq, __LINE__);
  err += compare_binary_op(m_and, m_nan_and, __LINE__);
  err += compare_binary_op(m_or, m_nan_or, __LINE__);
  err += compare_unary_op(m_not, m_nan_not, __LINE__); // TODO: errors!
  // TODO: m_cond to test
  err += compare_binary_op(m_min, m_nan_min, __LINE__);
  err += compare_binary_op(m_max, m_nan_max, __LINE__);
  err += compare_unary_op(m_present, m_nan_present, __LINE__);
  err += compare_unary_op(m_null, m_nan_null, __LINE__);
  err += compare_unary_op(m_round, m_nan_round, __LINE__);
  err += compare_unary_op(m_floor, m_nan_floor, __LINE__);
  // TODO: err += compare_unary_op(m_is_defined_true, m_nan_is_defined_true, __LINE__);
  // TODO: m_is_defined_false
  // TODO: m_nan_literal
  // TODO: m_array_index
  // TODO: m_multimax

  return err;
}

int main(void)
{
  int err = 0;

  err += compare_operators();

  return err;
}