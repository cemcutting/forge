#lang forge/froglet

option run_sterling off

abstract sig Node {}
one sig Data {
    seq: pfunc Int -> Node
}

one sig A, B, C, D extends Node{}

pred order {
    isSeqOf[Data.seq, Node]
    Data.seq[0] = A
    Data.seq[1] = B
    Data.seq[2] = A
    Data.seq[3] = C
    Data.seq[4] = D
    all i: Int | (not (i = 0 or i = 1 or i = 2 or i = 3 or i =4)) implies no Data.seq[i]
}

test expect {
    first: {order implies (seqFirst[Data.seq] = A)} is checked
    last: {order implies (seqLast[Data.seq] = D)} is checked
    idx: {order implies (idxOf[Data.seq, D] = 4)} is checked
    lastidx: {order implies (lastIdxOf[Data.seq, A] = 2)} is checked
    dups: {order implies (hasDups[Data.seq])} is checked
    notempty: {order implies (not isEmpty[Data.seq])} is checked
    idx_produces_first: {order implies (idxOf[Data.seq, A] = 0)} is checked
}