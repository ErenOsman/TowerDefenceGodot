class_name PhaseForecast
extends RefCounted
## The enemy phase played ahead (TurnForecast.Phase): each unit's casts, what everyone would lose, who would die.

## Each unit's casts in its turn, in the order the turns came: entity id → Array of ForecastStep.
var steps: Dictionary = {}

## HP + shield each entity would lose by the end of the phase (only those losing some): entity id → int.
var loss: Dictionary = {}

## Entities alive now that would die: a set (entity id → true).
var killed: Dictionary = {}

## The HP each entity would have afterwards (only those whose HP would change; 0 for the dead), e.g. for heals.
var hp: Dictionary = {}
