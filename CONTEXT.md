# Skillworks

The Claude Code skills that act across the 5thlayer repos, installed as the `skillworks` plugin from this repo's marketplace.

## Language

**Library**:
A 5thlayer mod made from libworks' template and released to Modrinth and CurseForge on its own version. Groundworks, Beltworks, Pipeworks, Wireworks, Craftworks and Fieldworks are Libraries.
_Avoid_: dependency, extracted mod

**Showcase**:
The CurseForge modpack, `factoryworks-showcase`, that carries every Library beside third-party mods. It is no Library: it takes the Libraries from CurseForge, versions on its own, and releases through its own scripts.
_Avoid_: modpack, pack (alone, when a Library's pack authors are meant)

## Relationships

- A **Library** may require Groundworks, in a version range of its own
- A **Library**'s own tests live with the Library

## Flagged ambiguities

- A fork 5thlayer did not write, such as Researchd's, is not a **Library**.
