# Carve: a Library out of the Pack's code

Groundworks was carved out of `core/placement/`, Craftworks out of `core/assembler/`. The mechanic's code and its JVM tests move to a new repo made from libworks; whatever of it depends on the Pack becomes a Binding, which stays.

1. **Set up the repo.** Do `SKILL.md` step 4 now, on the empty template, so the code lands on a green CI.

2. **Draw the line.** List every class in the mechanic's package, and for each import from elsewhere in the Pack decide:
   - it belongs to the mechanic, so it moves too;
   - it is a Pack setting the mechanic reads (a Factorio number, a tier, a tag, a refusal, a recipe): the Library gets an extension point and the Pack's side becomes a Binding;
   - it is a Pack class that uses the mechanic: it stays and later imports the Library.

   Extension points are open types and events the Pack plugs into, as in Groundworks' ADR 0001 ("consumers plug in through open types and events"): a registry, an interface, a data-driven default. A Library must work with no Pack (criterion 4), so every extension point needs a default that plays without one. Done when the user has approved the list of what moves, what becomes a Binding and each extension point, with its default.

3. **Move the code.** Copy the moving classes into `src/main/java/io/github/_5thlayer/<mod_id>/`, renamed to the package, and their JVM tests into `src/test/java/io/github/_5thlayer/<mod_id>/`. Add the extension points with their defaults. Assets and data the mechanic owns move under `src/main/resources/assets/<mod_id>/` and `data/<mod_id>/`, which renames their ids from `planetaryfactory:` to `<mod_id>:`. Every Java file carries the template's SPDX header, and `reuse lint` stays green. The Pack keeps its copies until step 8's switch commit, so it keeps building meanwhile. Done when `sh ./gradlew build` passes in the Library with the moved JVM tests green, and CI is green on the push.

4. **List the Bindings.** List, for the switch commit, the Pack code that will configure the Library through each extension point, and the GameTests that will assert it. The Pack's owner writes them in step 8's commit; you can try them against your checkout with `-PsiblingBuilds=<mod_id>`. Done when every Pack setting from step 2 has its Binding named.

Then go on to `SKILL.md` step 5.

## Ids in saves

Moving the mechanic's blocks and items from `planetaryfactory:` to `<mod_id>:` drops them from existing saves unless the Pack remaps them. Ask the user which, and record the answer in the Library's `CHANGELOG.md` `0.1.0` entry and in the Pack's switch commit.
