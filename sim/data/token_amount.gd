class_name TokenAmount
extends RefCounted
## A number of tokens of one kind: a form's unlock cost entry, or a level's drop entry
## (`{ "token": "Tokens/Fire Arrow", "amount": 1 }`).

var token: TokenAsset = null
var amount: int = 1
