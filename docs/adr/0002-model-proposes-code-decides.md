# The model proposes, the code decides

The LLM never changes game state directly. It proposes actions through tool calls (reveal a Secret, open a door) and the code validates each one against the state and the conditions declared in data (Trust, topic, threshold). If a proposal is invalid, the code rejects it and returns the error to the model. This guards against hallucination and prompt injection, and it is the standard pattern for production agents.
