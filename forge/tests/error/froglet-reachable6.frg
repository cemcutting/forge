#lang forge/froglet
option run_sterling off

-- error: useless field, cannot reach a sig that might use the field

sig Node {}
sig NA extends Node {
  na: lone NA
}
sig NB extends Node {
  nb: lone NB
}

reach6: run {
  all n: NA | reachable[n, n.na, na, nb]
}

