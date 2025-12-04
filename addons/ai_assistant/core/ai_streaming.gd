@tool
class_name AIStreaming
extends RefCounted

## Handles streaming HTTP requests to AI providers (Anthropic, OpenAI)

signal chunk_received(text: String)
signal stream_finished(full_response: String)
signal stream_error(error: String)

var http_client: HTTPClient = null
var stream_buffer := ""
var stream_content := ""
var provider := "anthropic"
var is_streaming := false

const ANTHROPIC_URL := "api.anthropic.com"
const OPENAI_URL := "api.openai.com"


func start_stream(api_key: String, p_provider: String, model: String, messages: Array, system_prompt: String) -> void:
	provider = p_provider
	stream_buffer = ""
	stream_content = ""
	is_streaming = true

	http_client = HTTPClient.new()

	var host := ANTHROPIC_URL if provider == "anthropic" else OPENAI_URL
	var err := http_client.connect_to_host(host, 443, TLSOptions.client())

	if err != OK:
		stream_error.emit("Failed to connect: " + error_string(err))
		return

	# Wait for connection (with timeout)
	var timeout := 10.0
	var elapsed := 0.0
	while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		http_client.poll()
		await Engine.get_main_loop().process_frame
		elapsed += 0.016
		if elapsed > timeout:
			stream_error.emit("Connection timeout")
			cleanup()
			return

	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		stream_error.emit("Failed to connect: status " + str(http_client.get_status()))
		cleanup()
		return

	# Build request
	var headers: PackedStringArray
	var body: String
	var path: String

	if provider == "anthropic":
		headers = PackedStringArray([
			"Content-Type: application/json",
			"x-api-key: " + api_key,
			"anthropic-version: 2023-06-01"
		])
		path = "/v1/messages"
		body = JSON.stringify({
			"model": model,
			"max_tokens": 8192,
			"stream": true,
			"system": system_prompt,
			"messages": messages
		})
	else:
		headers = PackedStringArray([
			"Content-Type: application/json",
			"Authorization: Bearer " + api_key
		])
		path = "/v1/chat/completions"

		var openai_messages: Array = [{"role": "system", "content": system_prompt}]
		openai_messages.append_array(messages)

		body = JSON.stringify({
			"model": model,
			"max_tokens": 8192,
			"stream": true,
			"messages": openai_messages
		})

	err = http_client.request(HTTPClient.METHOD_POST, path, headers, body)
	if err != OK:
		stream_error.emit("Request failed: " + error_string(err))
		cleanup()
		return

	# Process stream
	_process_stream()


func _process_stream() -> void:
	while is_streaming and http_client:
		http_client.poll()
		var status := http_client.get_status()

		if status == HTTPClient.STATUS_REQUESTING:
			await Engine.get_main_loop().process_frame
			continue

		if status == HTTPClient.STATUS_BODY:
			if http_client.has_response():
				var chunk := http_client.read_response_body_chunk()
				if chunk.size() > 0:
					var chunk_str := chunk.get_string_from_utf8()
					_process_chunk(chunk_str)

			await Engine.get_main_loop().process_frame
			continue

		if status == HTTPClient.STATUS_CONNECTED:
			# Done
			break

		if status == HTTPClient.STATUS_CONNECTION_ERROR or status == HTTPClient.STATUS_CANT_CONNECT:
			stream_error.emit("Connection error")
			break

		await Engine.get_main_loop().process_frame

	_finish()


func _process_chunk(chunk: String) -> void:
	stream_buffer += chunk

	# Process complete SSE events
	while true:
		var newline_pos := stream_buffer.find("\n\n")
		if newline_pos == -1:
			newline_pos = stream_buffer.find("\r\n\r\n")
		if newline_pos == -1:
			break

		var event := stream_buffer.substr(0, newline_pos)
		stream_buffer = stream_buffer.substr(newline_pos + 2)
		if stream_buffer.begins_with("\n"):
			stream_buffer = stream_buffer.substr(1)
		if stream_buffer.begins_with("\r\n"):
			stream_buffer = stream_buffer.substr(2)

		_parse_sse_event(event)


func _parse_sse_event(event: String) -> void:
	for line in event.split("\n"):
		line = line.strip_edges()

		if line.begins_with("data: "):
			var data := line.substr(6)

			if data == "[DONE]":
				return

			var json := JSON.new()
			if json.parse(data) == OK:
				var result = json.get_data()

				var text := ""
				if provider == "anthropic":
					# Anthropic format
					if result is Dictionary:
						if result.get("type") == "content_block_delta":
							var delta = result.get("delta", {})
							text = delta.get("text", "")
				else:
					# OpenAI format
					if result is Dictionary:
						var choices = result.get("choices", [])
						if choices.size() > 0:
							var delta = choices[0].get("delta", {})
							text = delta.get("content", "")

				if not text.is_empty():
					stream_content += text
					chunk_received.emit(text)


func _finish() -> void:
	is_streaming = false
	stream_finished.emit(stream_content)
	cleanup()


func cleanup() -> void:
	is_streaming = false
	if http_client:
		http_client = null


func stop() -> void:
	is_streaming = false
	cleanup()
