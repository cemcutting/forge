#lang forge

option run_sterling off


option verbose 0 
option problem_type temporal

sig Node {
    var edge: set Node,
    var fruit: set Node
}

pred F1 {
    all n1, n2 : Node | n1->n2 in (edge + fruit)
}

pred F2 {
    some n1, n2, n3: Node | (n1->n2 + n1->n3) in edge and n2->n3 not in fruit
}

pred F3 {
    #(edge + fruit) < add[#edge, #edge]
}


test expect{
    NotUntil12_thm: {(not F1 until F2) iff ((not F1) until F2)} is theorem
    NotUntil12_sat: {not ((not F1 until F2) iff (not (F1 until F2)))} is sat
    NotUntil13_thm: {(not F1 until F3) iff ((not F1) until F3)} is theorem
    NotUntil13_sat: {not ((not F1 until F3) iff (not (F1 until F3)))} is sat
    NotUntil23_thm: {(not F2 until F3) iff ((not F2) until F3)} is theorem
    NotUntil23_sat: {not ((not F2 until F3) iff (not (F2 until F3)))} is sat

    AlwaysUntil12_thm: {(always F1 until F2) iff ((always F1) until F2)} is theorem
    AlwaysUntil12_sat: {always ((always F1 until F2) iff (always (F1 until F2)))} is sat
    AlwaysUntil13_thm: {(always F1 until F3) iff ((always F1) until F3)} is theorem
    AlwaysUntil13_sat: {always ((always F1 until F3) iff (always (F1 until F3)))} is sat
    AlwaysUntil23_thm: {(always F2 until F3) iff ((always F2) until F3)} is theorem
    AlwaysUntil23_sat: {always ((always F2 until F3) iff (always (F2 until F3)))} is sat
    
    EventuallyUntil12_thm: {(eventually F1 until F2) iff ((eventually F1) until F2)} is theorem
    EventuallyUntil12_sat: {eventually ((eventually F1 until F2) iff (eventually (F1 until F2)))} is sat
    EventuallyUntil13_thm: {(eventually F1 until F3) iff ((eventually F1) until F3)} is theorem
    EventuallyUntil13_sat: {eventually ((eventually F1 until F3) iff (eventually (F1 until F3)))} is sat
    EventuallyUntil23_thm: {(eventually F2 until F3) iff ((eventually F2) until F3)} is theorem
    EventuallyUntil23_sat: {eventually ((eventually F2 until F3) iff (eventually (F2 until F3)))} is sat

    Notreleases12_thm: {(not F1 releases F2) iff ((not F1) releases F2)} is theorem
    Notreleases12_sat: {not ((not F1 releases F2) iff (not (F1 releases F2)))} is sat
    Notreleases13_thm: {(not F1 releases F3) iff ((not F1) releases F3)} is theorem
    Notreleases13_sat: {not ((not F1 releases F3) iff (not (F1 releases F3)))} is sat
    Notreleases23_thm: {(not F2 releases F3) iff ((not F2) releases F3)} is theorem
    Notreleases23_sat: {not ((not F2 releases F3) iff (not (F2 releases F3)))} is sat


    UntilAnd_thm: {(F1 and F2 until F3) iff (F1 and (F2 until F3))} is theorem
    UntilAnd_sat: {not ((F1 and F2 until F3) iff ((F1 and F2) until F3))} is sat

    ImpliesIff_thm: {(F1 => F2 <=> F3) iff ((F1 => F2) <=> F3)} is theorem
    ImpliesIff_sat: {not ((F1 => F2 <=> F3) iff (F1 => (F2 <=> F3)))} is sat

    IffOr_thm: {(F1 || F2 <=> F3) iff (F1 || (F2 <=> F3))} is theorem
    IffOr_sat: {not ((F1 || F2 <=> F3) iff ((F1 || F2) <=> F3))} is sat
}
