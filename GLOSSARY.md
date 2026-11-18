# NPC with LLM

A Godot game whose NPC converses through an LLM. It is both a portfolio piece and a vehicle for learning about agents, evolving in Stages.

## Language

### Characters and setting

**NPC**:
The mysterious, fantasy-toned hooded figure (in game: the Keeper / Guardião) the Player talks to; it talks about the author's portfolio, AI and the agent market.
_Avoid_: Bot, assistant, chatbot (except to name Stage 2)

**Player**:
The portfolio visitor (e.g. a recruiter or developer) who talks to the NPC, seen in first person.
_Avoid_: User, visitor, client

**Lore**:
The NPC's background knowledge (portfolio, AI, market, fantasy world), retrieved via RAG from Stage 4 on.
_Avoid_: Knowledge base, documents

### Language rules

**Game Language**:
The language (Portuguese or English) chosen in the menu; it alone decides which language the NPC speaks, whatever language the Player writes in.
_Avoid_: Locale, idiom, player language

### Quest

**Quest**:
The Player's short goal: uncover the NPC's Secrets by talking to it.
_Avoid_: Mission, challenge

**Secret**:
A piece of portfolio information (projects, stack, market vision) the NPC only reveals once its conditions are met.
_Avoid_: Easter egg, unlock

**Trust**:
A 0-100 gauge the NPC keeps about the Player; it rises with relevant, polite interaction, drops with provocation or jailbreak attempts, and unlocks Secrets past a threshold.
_Avoid_: Affinity, reputation

### Project structure

**Stage**:
One step in the NPC's evolution, each adding a capability: Godot interface with a Mock, structured-JSON chatbot, agent with tools and memory, then agent with Lore RAG.
_Avoid_: Phase, version, level

**Agent Service**:
The separate Python service that hosts the NPC's brain; the Godot game only queries it.
_Avoid_: Backend, API, server

**Mock**:
The simulated NPC of Stage 1, returning canned replies in the final schema, without an LLM.
_Avoid_: Fake, stub
