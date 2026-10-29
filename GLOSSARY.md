# Skillworks

The Claude Code skills that act across the 5thlayer repos, installed as the `skillworks` plugin from this repo's marketplace.

## Language

**Module**:
A 5thlayer mod made from libworks' template and released to Modrinth and CurseForge on its own version. Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks and Fieldworks are Modules.
_Avoid_: Library, Binding, dependency, extracted mod

**Showcase**:
The CurseForge modpack, `factoryworks-showcase`, that carries every Module beside third-party mods. It is no Module: it takes the Modules from CurseForge, versions on its own, and releases through its own scripts.
_Avoid_: modpack, pack (alone, when a Module's pack authors are meant)

## Relationships

- A **Module** may require Groundworks, in a version range of its own
- A **Module**'s own tests live with the Module

## Flagged ambiguities

- A fork 5thlayer did not write, such as Researchd's, is not a **Module**.
