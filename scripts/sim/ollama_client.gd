class_name OllamaClient
extends RefCounted

## Thin async client for a local Ollama server. The pure helpers (parse_models,
## build_chat_body, extract_content) are unit-tested; the HTTP wrappers just move
## bytes, so the integration works the moment Ollama is running and degrades
## gracefully (returns []/{}) when it is not.
##
## Ollama API: GET /api/tags lists installed models; POST /api/chat runs one
## turn. We force `format:"json"` so the model returns parseable settings.

const DEFAULT_HOST := "http://localhost:11434"
const TIMEOUT_S := 120.0


# ---- pure helpers (unit-tested) ----

static func parse_models(data: Dictionary) -> Array:
	var out: Array = []
	for m in data.get("models", []):
		if m is Dictionary and m.has("name"):
			out.append(String(m["name"]))
	out.sort()
	return out


static func build_chat_body(model: String, system_prompt: String, user_prompt: String) -> Dictionary:
	return {
		"model": model,
		"stream": false,
		"format": "json",
		"options": {"temperature": 0.6},
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": user_prompt},
		],
	}


# Pull the assistant's JSON object out of an /api/chat response.
static func extract_content(response: Dictionary) -> Dictionary:
	var content := String(response.get("message", {}).get("content", ""))
	if content.is_empty():
		return {}
	var parsed := _parse_dict(content)
	if not parsed.is_empty():
		return parsed
	# Robustness: some models wrap JSON in ```json fences or add prose. Strip a code
	# fence if present, then parse the first {...} block. Lets fenced/chatty models
	# (e.g. coder models) participate instead of silently falling back to hill-climb.
	var s := content
	var fence := s.find("```")
	if fence != -1:
		s = s.substr(fence + 3)
		if s.to_lower().begins_with("json"):
			s = s.substr(4)
		var fence_end := s.find("```")
		if fence_end != -1:
			s = s.substr(0, fence_end)
	var lo := s.find("{")
	var hi := s.rfind("}")
	if lo != -1 and hi > lo:
		parsed = _parse_dict(s.substr(lo, hi - lo + 1))
		if not parsed.is_empty():
			return parsed
	return {}


static func _parse_dict(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data = json.data
	return data if data is Dictionary else {}


# ---- async HTTP wrappers ----

static func list_models(tree: SceneTree, host := DEFAULT_HOST) -> Array:
	var res := await _request(tree, host + "/api/tags", HTTPClient.METHOD_GET, "")
	return parse_models(res) if not res.is_empty() else []


static func chat(tree: SceneTree, model: String, system_prompt: String, user_prompt: String,
		host := DEFAULT_HOST) -> Dictionary:
	var body := build_chat_body(model, system_prompt, user_prompt)
	var res := await _request(tree, host + "/api/chat", HTTPClient.METHOD_POST, JSON.stringify(body))
	return extract_content(res) if not res.is_empty() else {}


static func is_available(tree: SceneTree, host := DEFAULT_HOST) -> bool:
	var res := await _request(tree, host + "/api/tags", HTTPClient.METHOD_GET, "")
	return not res.is_empty()


static func _request(tree: SceneTree, url: String, method: int, body_str: String) -> Dictionary:
	if tree == null:
		return {}
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_S
	tree.root.add_child(http)
	var headers := ["Content-Type: application/json"]
	var err := http.request(url, headers, method, body_str)
	if err != OK:
		http.queue_free()
		return {}
	var result: Array = await http.request_completed
	http.queue_free()
	# result = [result, response_code, headers, body]
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		return {}
	var text := (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
