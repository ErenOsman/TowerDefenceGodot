class_name Requirements
extends RefCounted
## What a formula reads; compared against what an evaluation point provides.

var subjects: int = SubjectNeeds.None
## Set of variable names ({name: true}), in first-read order.
var vars: Dictionary = {}
var uses_random: bool = false
## Subject + stat/query pairs, e.g. "Target.MaxHP", for error messages.
var subject_reads: Array[String] = []
