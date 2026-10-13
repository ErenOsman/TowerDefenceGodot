class_name Validator
extends RefCounted
## One validator for drawers, Validate All, build gates and tests.

## Returns the errors for the expression in the given slot; empty when valid.
## slot_name "" (C# null) means spec.name.
static func validate(expression, spec: ContextSpec, vocab: Vocabulary, slot_name = null) -> Array[String]:
	var errors: Array[String] = []
	var slot: String = spec.name if slot_name == null or slot_name == "" else slot_name
	if expression == null: expression = ""

	if expression.strip_edges().is_empty():
		if spec.expects == ValueKind.Number: errors.append("%s is empty." % slot)
		return errors # an empty condition means always true

	var node := vocab.compile(expression)
	if node == null:
		errors.append("%s: %s" % [slot, vocab.last_error])
		return errors

	if node.kind != spec.expects:
		errors.append("%s must produce a %s, but '%s' is a %s." % [slot, "boolean" if spec.expects == ValueKind.Bool else "number", expression, "boolean" if node.kind == ValueKind.Bool else "number"])

	var req := Requirements.new()
	node.collect(req)

	if req.uses_random and not spec.allow_random:
		errors.append("%s uses rand(), which conditions may not use; put the chance in a separate field." % slot)

	for read in req.subject_reads:
		var subject := read.substr(0, read.find("."))
		var need := SubjectNeeds.Source if subject == "Source" else (SubjectNeeds.Target if subject == "Target" else SubjectNeeds.Self)
		if (spec.subjects & need) == 0:
			errors.append("%s reads %s, but %s has no %s." % [slot, read, spec.name, subject.to_lower()])

	for v in req.vars:
		if not spec.vars.has(v):
			errors.append("%s reads %s, but %s is not produced yet in %s." % [slot, v, v, spec.name])

	return errors
