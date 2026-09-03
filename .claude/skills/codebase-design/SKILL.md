---
name: codebase-design
description: Shared vocabulary for designing deep modules. Use when the user wants to design or improve a module's interface, find deepening opportunities, decide where a seam goes, make code more testable or AI-navigable, or when another skill needs the deep-module vocabulary.
---

# Codebase Design

Design **deep modules**: a lot of behaviour behind a small interface, at a clean seam, testable through
that interface. **Use this language exactly** — swapping in "component", "service", "API" or "boundary"
is what this skill exists to stop.

## Glossary

**Module** — anything with an interface and an implementation. Scale-agnostic on purpose: a function, a
class, a package, a tier-spanning slice. _Avoid_: unit, component, service.

**Interface** — everything a caller must know to use it correctly: the type signature, and also
invariants, ordering constraints, error modes, required configuration, performance. _Avoid_: API,
signature — both name only the type-level surface.

**Implementation** — what is inside. Distinct from **adapter**: a thing can be a small adapter with a
large implementation (a Postgres repo) or a large adapter with a small one (an in-memory fake).

**Depth** — leverage at the interface: how much behaviour a caller or a test can exercise per unit of
interface they must learn. **Deep** = much behaviour behind a small interface. **Shallow** = the interface
is nearly as complex as the implementation.

**Seam** _(Michael Feathers)_ — a place where behaviour can be altered without editing in that place;
the *location* the interface lives at. **Where the seam goes is its own decision**, separate from what
sits behind it. _Avoid_: boundary, which is overloaded with DDD's bounded context.

**Adapter** — a concrete thing satisfying an interface at a seam. It names a *role*, not a substance.

**Leverage** — what callers get from depth. **Locality** — what maintainers get: change, bugs and
verification concentrate in one place. Fix once, fixed everywhere.

## Principles

- **Depth is a property of the interface, not the implementation.** A deep module may be built inside
  from small swappable parts; they are just not part of the interface
- **The deletion test.** Imagine deleting the module. Complexity vanishes → it was a pass-through.
  Complexity reappears across N callers → it was earning its keep
- **The interface is the test surface.** Callers and tests cross the same seam. Wanting to test *past* it
  means the module is the wrong shape
- **One adapter is a hypothetical seam; two is a real one.** Do not introduce one unless something varies

**Designing an interface**: can I cut methods · can I simplify the parameters · can I hide more inside.

## Designing for testability

**Accept dependencies, do not create them** — a seed created inside is unreachable, so the same input
gives two answers:

```gdscript
func resolve(fight: Fight, rng: RandomNumberGenerator) -> void: # testable, deterministic
func resolve(fight: Fight) -> void: # rng made inside — unreachable
```

**Return results, do not produce side effects** — the net asserts the number without a body existing:

```gdscript
func damage_for(attacker: Unit, target: Unit) -> int: # testable
func strike(attacker: Unit, target: Unit) -> void: # build the whole fight to read one number
```

**Small surface area.** Fewer methods, fewer tests; fewer parameters, simpler setup.

## Rejected framings

- **Depth as a lines-of-implementation ratio** (Ousterhout) — it rewards padding. Depth here is leverage
- **"Interface" as a class's public methods** — too narrow; it is every fact a caller must know
- **"Boundary"** — say **seam** or **interface**

## Going deeper

- **Deepening a cluster given its dependencies** — [DEEPENING.md](DEEPENING.md)
- **Exploring alternative interfaces** — [DESIGN-IT-TWICE.md](DESIGN-IT-TWICE.md)
