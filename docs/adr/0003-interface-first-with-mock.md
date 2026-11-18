# Interface first, with a Mock NPC that honors the schema

Stage 1 builds the point-and-click interface in Godot talking to a Mock that returns sample JSON in the final schema. The real Agent Service (Stage 2) replaces the Mock by changing only the client's URL. This pins the JSON contract from day one and keeps interface work from waiting on the LLM, at the cost of the schema having to anticipate fields only used later (for example `awaiting` and `suggestions`).
