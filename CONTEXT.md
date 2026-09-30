# Skillworks

The Claude Code skills that act across the 5thlayer repos, installed as the `skillworks` plugin from this repo's marketplace. The rules behind the terms below are FactoryWorks' ADR-0090, "Extracting a Library".

## Language

**Pack**:
FactoryWorks, the modpack that brings Factorio's rules to Minecraft.

**Library**:
A 5thlayer mod the **Pack** consumes as a local jar pinned in the Pack's `data/pack/local-jars.json`. Beltworks, Groundworks and Craftworks are Libraries.
_Avoid_: dependency, extracted mod

**Binding**:
The **Pack**'s code that configures a **Library** for Factorio's rules, and the GameTests asserting that configuration. A Binding stays in the Pack when its Library leaves it.
_Avoid_: glue, adapter, integration

## Relationships

- The **Pack** consumes many **Libraries**, each pinned to one version
- A **Library** has at most one **Binding**, which lives in the **Pack**
- A **Library**'s own tests live with the Library; its **Binding**'s tests live with the Pack

## Flagged ambiguities

- A fork the Pack consumes as a pinned local jar but 5thlayer did not write, such as Researchd's, is not a **Library**.
