class_name SubjectNeedsUtil
extends RefCounted
## internal static helper (C# SubjectNeedsUtil): the SubjectNeeds flag of a Subject.

static func of(s: int) -> int:
	return SubjectNeeds.Source if s == Subject.Source else (SubjectNeeds.Target if s == Subject.Target else SubjectNeeds.Self)
