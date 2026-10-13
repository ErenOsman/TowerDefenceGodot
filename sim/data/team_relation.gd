class_name TeamRelation
extends RefCounted
## A relation between two teams (GameRulesAsset.relations); pairs not listed: same team Ally, otherwise Enemy.

var team_a: int = 0
var team_b: int = 1
var relation: int = Relation.Enemy
