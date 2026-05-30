# Honcho TypeScript SDK parity matrix

Date: 2026-05-30
Source of truth: `@honcho-ai/sdk@2.1.2` TypeScript SDK (`dist/`, API version `/v3`, default base URL `https://api.honcho.dev`).

This checklist maps every public TypeScript SDK concept and method to the target Honchox Elixir SDK. Existing Honchox modules are noted where they partially cover the endpoint, but the target API is struct-first and SDK-shaped.

## Translation rules

- TypeScript camelCase options become Elixir snake_case options.
- Wire payloads remain the API's snake_case shape.
- Fallible Elixir calls return `{:ok, value}` or `{:error, %Honchox.Error{}}`.
- Resource-returning calls should return structs (`%Honchox.Peer{}`, `%Honchox.Session{}`, `%Honchox.Message{}`, etc.), not raw maps.
- List calls should return `%Honchox.Page{items, page, size, total, pages}` with transformed struct items.
- Workspace-scoped high-level calls must ensure the workspace exists, matching the TypeScript SDK's memoized `POST /v3/workspaces` behavior. Honchox may do this statelessly per high-level operation.

## Public concepts and target structs

| TypeScript concept | Target Elixir concept | Current status | Notes |
| --- | --- | --- | --- |
| `Honcho` | `%Honchox.Client{}` plus `Honchox` entry functions | Pending | Current `%Honchox{}` exists but defaults/base/workspace semantics diverge. |
| `Peer` | `%Honchox.Peer{}` | Pending | Current `Honchox.Peers` returns raw maps. |
| `PeerContext` | `%Honchox.PeerContext{}` | Pending | Fields: `peer_id`, `target_id`, `representation`, `peer_card`. |
| `Session` | `%Honchox.Session{}` | Pending | Current `Honchox.Sessions` returns raw maps. |
| `SessionContext` | `%Honchox.SessionContext{}` | Pending | Must include `to_open_ai/2` and `to_anthropic/2`. |
| `SessionSummaries` | `%Honchox.SessionSummaries{}` | Pending | Contains `short_summary` and `long_summary`. |
| `Summary` | `%Honchox.Summary{}` | Pending | Used by session context/summaries. |
| `MessageInput` | `%Honchox.MessageInput{}` or `%Honchox.Message{}` input mode | Pending | Produced synchronously by `Honchox.Peer.message/3`. |
| `Message` | `%Honchox.Message{}` | Pending | Current message endpoints return maps. |
| `Conclusion` | `%Honchox.Conclusion{}` | Pending | Current `Honchox.Conclusions` returns maps. |
| `ConclusionScope` | `%Honchox.ConclusionScope{}` or scoped functions under `Honchox.Conclusions` | Pending | Prefer struct to mirror SDK property/method chaining. |
| `Page<T>` | `%Honchox.Page{}` | Pending | Include current-page items and pagination metadata. |
| `QueueStatus` | `%Honchox.QueueStatus{}` | Pending | Could be a struct because shape is known. |
| HTTP errors (`HonchoError` and subclasses) | `%Honchox.Error{}` | Partial | Existing error struct can be retained/refined. |
| Streaming (`Peer.chatStream`, `DialecticStreamResponse` / `DialecticStream`) | stream enumerable / callback API | Pending | No current Elixir equivalent. |

## Client / workspace matrix

| TypeScript method | Target Elixir function | HTTP method | Path | Query params | Body shape | Return value | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `new Honcho(options)` | `Honchox.new/1` | none | none | none | none | `%Honchox.Client{}` | Defaults: `workspace_id` option, `HONCHO_WORKSPACE_ID`, then `"default"`; `base_url` option, `HONCHO_URL`, environment `:local` -> `http://localhost:8000`, otherwise `https://api.honcho.dev`; `api_key` option or `HONCHO_API_KEY`. Current default is wrong (`honcho.ai`). |
| internal `_ensureWorkspace()` | internal `Honchox.API.Workspaces.ensure/1` | POST | `/v3/workspaces` | none | `%{id: workspace_id, metadata?: map, configuration?: workspace_config_api}` | ignored / workspace response internally | TypeScript memoizes once. Honchox must preserve semantic guarantee without hidden mutable process state. |
| `honcho.peer(id, options)` | `Honchox.peer(client, id, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/peers` | none | `%{id: id, metadata?: map, configuration?: %{observe_me: boolean \\ nil}}` | `{:ok, %Honchox.Peer{}}` | Existing equivalent: `Honchox.Peers.get_or_create/3`, pending struct return and client-level workspace. |
| `honcho.peers(options)` | `Honchox.peers(client, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/peers/list` | `page`, `size`, `reverse="true"` when true | `%{filters: filters}` | `{:ok, %Honchox.Page{items: [%Honchox.Peer{}]}}` | Accept legacy raw filters only if desired; SDK treats raw object as `filters`. Current `Honchox.Peers.list/2` partial. |
| `honcho.session(id, options)` | `Honchox.session(client, id, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/sessions` | none | `%{id: id, metadata?: map, configuration?: session_config_api}` | `{:ok, %Honchox.Session{}}` | Existing `Honchox.Sessions.get_or_create/3` partial. |
| `honcho.sessions(options)` | `Honchox.sessions(client, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/sessions/list` | `page`, `size`, `reverse="true"` when true | `%{filters: filters}` | `{:ok, %Honchox.Page{items: [%Honchox.Session{}]}}` | Existing `Honchox.Sessions` lacks top-level SDK entry point. |
| `honcho.getMetadata()` | `Honchox.get_metadata(client)` | POST | `/v3/workspaces` | none | `%{id: workspace_id}` | `{:ok, map}` | SDK uses get-or-create response and returns `metadata || {}`. Pending. |
| `honcho.setMetadata(metadata)` | `Honchox.set_metadata(client, metadata)` | PUT | `/v3/workspaces/{workspace_id}` | none | `%{metadata: metadata}` | `:ok` | Update client cache not needed in immutable design unless returning updated client. Pending. |
| `honcho.getConfiguration()` | `Honchox.get_configuration(client)` | POST | `/v3/workspaces` | none | `%{id: workspace_id}` | `{:ok, map}` | Convert API snake_case config to Elixir snake_case fields. Pending. |
| `honcho.setConfiguration(configuration)` | `Honchox.set_configuration(client, configuration)` | PUT | `/v3/workspaces/{workspace_id}` | none | `%{configuration: workspace_config_api}` | `:ok` | Config keys translate to snake_case wire format. Pending. |
| `honcho.refresh()` | `Honchox.refresh(client)` | POST | `/v3/workspaces` | none | `%{id: workspace_id}` | `{:ok, %Honchox.Client{}}` or `{:ok, workspace}` | TS refreshes mutable cache. Elixir should return updated immutable client or expose as workspace fetch. Pending decision. |
| `honcho.workspaces(options)` | `Honchox.workspaces(client, opts \\ [])` | POST | `/v3/workspaces/list` | `page`, `size` | `%{filters: filters}` | `{:ok, %Honchox.Page{items: [workspace_id]}}` | Existing `Honchox.Workspaces.list/2` partial. |
| `honcho.deleteWorkspace(workspaceId)` | `Honchox.delete_workspace(client, workspace_id)` | DELETE | `/v3/workspaces/{workspace_id}` | none | none | `:ok` | Existing `Honchox.Workspaces.delete/2`. |
| `honcho.search(query, options)` | `Honchox.search(client, query, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/search` | none | `%{query: query, filters?: filters, limit?: integer}` | `{:ok, [%Honchox.Message{}]}` | Existing `Honchox.Workspaces.search/3` partial. |
| `honcho.queueStatus(options)` | `Honchox.queue_status(client, opts \\ [])` | GET | `/v3/workspaces/{workspace_id}/queue/status` | `observer_id`, `sender_id`, `session_id` | none | `{:ok, %Honchox.QueueStatus{}}` | Options accept IDs or structs for observer/sender/session. Existing `Honchox.Workspaces.queue_status/2` partial. |
| `honcho.scheduleDream(options)` | `Honchox.schedule_dream(client, opts)` | POST | `/v3/workspaces/{workspace_id}/schedule_dream` | none | `%{observer: observer_id, observed: observed_id || observer_id, session_id?: session_id, dream_type: "omni"}` | `:ok` | Existing `Honchox.Workspaces.schedule_dream/2` partial. |
| `honcho.toString()` | `Inspect` implementation | none | none | none | none | string | Optional debug parity. |

## Peer matrix

| TypeScript method | Target Elixir function | HTTP method | Path | Query params | Body shape | Return value | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `peer.chat(query, options)` | `Honchox.Peer.chat(peer, query, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/peers/{peer_id}/chat` | none | `%{query: query, stream: false, target?: peer_id, session_id?: session_id, reasoning_level?: level}` | `{:ok, string | nil}` | Existing `Honchox.Peers.chat/4` partial. TS returns `response.content` or `null`. |
| `peer.chatStream(query, options)` | `Honchox.Peer.chat_stream(peer, query, opts \\ [])` | POST (SSE stream) | same as `chat` | none | same as chat with `stream: true` | stream result | Pending; no current equivalent. Must use SSE handling. |
| `peer.sessions(options)` | `Honchox.Peer.sessions(peer, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/peers/{peer_id}/sessions` | `page`, `size`, `reverse="true"` when true | `%{filters: filters}` | `{:ok, %Honchox.Page{items: [%Honchox.Session{}]}}` | Existing `Honchox.Peers.list_sessions/3` partial. |
| `peer.message(content, options)` | `Honchox.Peer.message(peer, content, opts \\ [])` | none | none | none | none | `%Honchox.MessageInput{peer_id, content, metadata, configuration, created_at}` | Synchronous factory; no API call. Pending. |
| `peer.getMetadata()` | `Honchox.Peer.get_metadata(peer)` | POST | `/v3/workspaces/{workspace_id}/peers` | none | `%{id: peer_id}` | `{:ok, map}` | Existing raw `get_or_create` can support. Pending struct method. |
| `peer.setMetadata(metadata)` | `Honchox.Peer.set_metadata(peer, metadata)` | PUT | `/v3/workspaces/{workspace_id}/peers/{peer_id}` | none | `%{metadata: metadata}` | `:ok` | Pending. |
| `peer.getConfiguration()` | `Honchox.Peer.get_configuration(peer)` | POST | `/v3/workspaces/{workspace_id}/peers` | none | `%{id: peer_id}` | `{:ok, %{observe_me: boolean | nil}}` | TS converts `observe_me` to `observeMe`; Elixir should expose `observe_me`. |
| `peer.setConfiguration(configuration)` | `Honchox.Peer.set_configuration(peer, config)` | PUT | `/v3/workspaces/{workspace_id}/peers/{peer_id}` | none | `%{configuration: %{observe_me: ...}}` | `:ok` | Pending. |
| `peer.refresh()` | `Honchox.Peer.refresh(peer)` | POST | `/v3/workspaces/{workspace_id}/peers` | none | `%{id: peer_id}` | `{:ok, %Honchox.Peer{}}` | TS mutates cache; Elixir should return refreshed struct. Pending. |
| `peer.search(query, options)` | `Honchox.Peer.search(peer, query, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/peers/{peer_id}/search` | none | `%{query: query, filters?: filters, limit?: integer}` | `{:ok, [%Honchox.Message{}]}` | Existing `Honchox.Peers.search/4` partial. |
| `peer.getCard(target?)` | `Honchox.Peer.get_card(peer, opts \\ [])` | GET | `/v3/workspaces/{workspace_id}/peers/{peer_id}/card` | `target` | none | `{:ok, [string] | nil}` | Existing `Honchox.Peers.get_card/3` partial. |
| `peer.card(target?)` | `Honchox.Peer.card(peer, opts \\ [])` | GET | same as `getCard` | `target` | none | `{:ok, [string] | nil}` | Deprecated alias in TS. Elixir may omit or mark deprecated. |
| `peer.setCard(peerCard, target?)` | `Honchox.Peer.set_card(peer, peer_card, opts \\ [])` | PUT | `/v3/workspaces/{workspace_id}/peers/{peer_id}/card` | `target` | `%{peer_card: [string]}` | `{:ok, [string] | nil}` | Existing `Honchox.Peers.set_card/4` partial. |
| `peer.representation(options)` | `Honchox.Peer.representation(peer, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/peers/{peer_id}/representation` | none | `%{session_id?: id, target?: id, search_query?: string, search_top_k?: integer, search_max_distance?: number, include_most_frequent?: boolean, max_conclusions?: integer}` | `{:ok, string}` | Existing `Honchox.Peers.representation/3` partial. `search_query` may be a message/content object in TS; Elixir can accept binary or `%Honchox.Message{}`. |
| `peer.context(options)` | `Honchox.Peer.context(peer, opts \\ [])` | GET | `/v3/workspaces/{workspace_id}/peers/{peer_id}/context` | `target`, `search_query`, `search_top_k`, `search_max_distance`, `include_most_frequent`, `max_conclusions` | none | `{:ok, %Honchox.PeerContext{}}` | Existing `Honchox.Peers.context/3` returns map. Must be explicit. |
| `peer.conclusions` | `Honchox.Peer.conclusions(peer)` | none | none | none | none | `%Honchox.ConclusionScope{observer_id: peer.id, observed_id: peer.id}` | Pending. Property in TS; function in Elixir. |
| `peer.conclusionsOf(target)` | `Honchox.Peer.conclusions_of(peer, target)` | none | none | none | none | `%Honchox.ConclusionScope{observer_id: peer.id, observed_id: target_id}` | Pending. |
| `peer.toString()` | `Inspect` implementation | none | none | none | none | string | Optional debug parity. |

## Session matrix

| TypeScript method | Target Elixir function | HTTP method | Path | Query params | Body shape | Return value | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `session.addPeers(peers)` | `Honchox.Session.add_peers(session, peers)` | POST | `/v3/workspaces/{workspace_id}/sessions/{session_id}/peers` | none | peer map directly, e.g. `%{"peer_id" => %{observe_me?: bool, observe_others?: bool}}` | `:ok` | Existing `Honchox.Sessions.add_peers/4` wraps body incorrectly per plan; fix to direct body. |
| `session.setPeers(peers)` | `Honchox.Session.set_peers(session, peers)` | PUT | same peers path | none | peer map directly | `:ok` | Existing `set_peers/4` wraps body incorrectly. |
| `session.removePeers(peers)` | `Honchox.Session.remove_peers(session, peers)` | DELETE | same peers path | none | `[peer_id, ...]` | `:ok` | Existing uses query string; SDK sends DELETE body. |
| `session.peers()` | `Honchox.Session.peers(session)` | GET | `/v3/workspaces/{workspace_id}/sessions/{session_id}/peers` | none | none | `{:ok, [%Honchox.Peer{}]}` | Existing `list_peers/3` partial. TS expects response with `items`. |
| `session.getPeerConfiguration(peer)` | `Honchox.Session.get_peer_configuration(session, peer)` | GET | `/v3/workspaces/{workspace_id}/sessions/{session_id}/peers/{peer_id}/config` | none | none | `{:ok, %{observe_me: bool | nil, observe_others: bool | nil}}` | Existing name `get_peer_config/4`; target should use full SDK wording or alias. |
| `session.setPeerConfiguration(peer, configuration)` | `Honchox.Session.set_peer_configuration(session, peer, config)` | PUT | same config path | none | `%{observe_me?: bool | nil, observe_others?: bool | nil}` | `:ok` | Existing `set_peer_config/5` partial. |
| `session.addMessages(messages)` | `Honchox.Session.add_messages(session, messages)` | POST | `/v3/workspaces/{workspace_id}/sessions/{session_id}/messages` | none | `%{messages: [%{peer_id, content, metadata?: map, configuration?: message_config_api, created_at?: iso8601}]}` | `{:ok, [%Honchox.Message{}]}` | Existing `add_messages/4` partial; must return structs. |
| `session.messages(options)` | `Honchox.Session.messages(session, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/sessions/{session_id}/messages/list` | `page`, `size`, `reverse="true"` when true | `%{filters: filters}` | `{:ok, %Honchox.Page{items: [%Honchox.Message{}]}}` | Existing `list_messages/3`; target name `messages/2`. |
| `session.getMetadata()` | `Honchox.Session.get_metadata(session)` | POST | `/v3/workspaces/{workspace_id}/sessions` | none | `%{id: session_id}` | `{:ok, map}` | Uses get-or-create response. Pending struct method. |
| `session.setMetadata(metadata)` | `Honchox.Session.set_metadata(session, metadata)` | PUT | `/v3/workspaces/{workspace_id}/sessions/{session_id}` | none | `%{metadata: metadata}` | `:ok` | Existing `update/4` partial. |
| `session.getConfiguration()` | `Honchox.Session.get_configuration(session)` | POST | `/v3/workspaces/{workspace_id}/sessions` | none | `%{id: session_id}` | `{:ok, session_config}` | Pending. |
| `session.setConfiguration(configuration)` | `Honchox.Session.set_configuration(session, config)` | PUT | `/v3/workspaces/{workspace_id}/sessions/{session_id}` | none | `%{configuration: session_config_api}` | `:ok` | Existing `update/4` partial. |
| `session.refresh()` | `Honchox.Session.refresh(session)` | POST | `/v3/workspaces/{workspace_id}/sessions` | none | `%{id: session_id}` | `{:ok, %Honchox.Session{}}` | TS mutates cache; Elixir returns refreshed struct. Pending. |
| `session.delete()` | `Honchox.Session.delete(session)` | DELETE | `/v3/workspaces/{workspace_id}/sessions/{session_id}` | none | none | `:ok` | Existing `Honchox.Sessions.delete/3` partial. |
| `session.clone(messageId?)` | `Honchox.Session.clone(session, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/sessions/{session_id}/clone` | `message_id` | none | `{:ok, %Honchox.Session{}}` | Existing sends params as body; SDK uses query. |
| `session.context(options)` | `Honchox.Session.context(session, opts \\ [])` | GET | `/v3/workspaces/{workspace_id}/sessions/{session_id}/context` | `tokens`, `summary`, `search_query`, `peer_target`, `peer_perspective`, `limit_to_session`, `search_top_k`, `search_max_distance`, `include_most_frequent`, `max_conclusions` | none | `{:ok, %Honchox.SessionContext{}}` | Existing `context/3` partial. Must support exact option translation. |
| `session.summaries()` | `Honchox.Session.summaries(session)` | GET | `/v3/workspaces/{workspace_id}/sessions/{session_id}/summaries` | none | none | `{:ok, %Honchox.SessionSummaries{}}` | Existing `summaries/3` returns map. |
| `session.search(query, options)` | `Honchox.Session.search(session, query, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/sessions/{session_id}/search` | none | `%{query: query, filters?: filters, limit?: integer}` | `{:ok, [%Honchox.Message{}]}` | Existing `search/4` partial. |
| `session.queueStatus(options)` | `Honchox.Session.queue_status(session, opts \\ [])` | GET | `/v3/workspaces/{workspace_id}/queue/status` | `session_id=session.id`, optional `observer_id`, `sender_id` | none | `{:ok, %Honchox.QueueStatus{}}` | Existing calls session-specific path; must change to workspace queue endpoint. |
| `session.uploadFile(file, peer, options)` | `Honchox.Session.upload_file(session, file, peer, opts \\ [])` | multipart POST | `/v3/workspaces/{workspace_id}/sessions/{session_id}/messages/upload` | none | multipart fields: `file`, `peer_id`, optional JSON `metadata`, optional JSON snake_case `configuration`, optional `created_at` | `{:ok, [%Honchox.Message{}]}` | Existing path diverges. File may be path, `{filename, binary}`, or upload struct. |
| `session.representation(peer, options)` | `Honchox.Session.representation(session, peer, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/peers/{peer_id}/representation` | none | `%{session_id: session.id, target?: id, search_query?: string, search_top_k?: integer, search_max_distance?: number, include_most_frequent?: boolean, max_conclusions?: integer}` | `{:ok, string}` | Existing uses suspected invalid session representation endpoint; must call peer representation endpoint. |
| `session.getMessage(messageId)` | `Honchox.Session.get_message(session, message_id)` | GET | `/v3/workspaces/{workspace_id}/sessions/{session_id}/messages/{message_id}` | none | none | `{:ok, %Honchox.Message{}}` | Existing `get_message/4` partial. |
| `session.updateMessage(message, metadata)` | `Honchox.Session.update_message(session, message_or_id, metadata)` | PUT | `/v3/workspaces/{workspace_id}/sessions/{session_id}/messages/{message_id}` | none | `%{metadata: metadata || %{}}` | `{:ok, %Honchox.Message{}}` | Existing `update_message/5` partial. |
| `session.toString()` | `Inspect` implementation | none | none | none | none | string | Optional debug parity. |

## Conclusions matrix

| TypeScript method | Target Elixir function | HTTP method | Path | Query params | Body shape | Return value | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `peer.conclusions` | `Honchox.Peer.conclusions(peer)` | none | none | none | none | `%Honchox.ConclusionScope{observer_id: peer.id, observed_id: peer.id}` | Scope constructor only. Pending. |
| `peer.conclusionsOf(target)` | `Honchox.Peer.conclusions_of(peer, target)` | none | none | none | none | `%Honchox.ConclusionScope{observer_id: peer.id, observed_id: target_id}` | Scope constructor only. Pending. |
| `scope.list(options)` | `Honchox.ConclusionScope.list(scope, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/conclusions/list` | `page` default `1`, `size` default `50`, `reverse="true"` when true | `%{filters: %{observer_id: scope.observer_id, observed_id: scope.observed_id, session_id?: session_id}}` | `{:ok, %Honchox.Page{items: [%Honchox.Conclusion{}]}}` | Existing `Honchox.Conclusions.list/2` partial but not scoped struct. |
| `scope.query(query, topK = 10, distance?)` | `Honchox.ConclusionScope.query(scope, query, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/conclusions/query` | none | `%{query: query, top_k: top_k, distance?: distance, filters: %{observer_id, observed_id}}` | `{:ok, [%Honchox.Conclusion{}]}` | Existing `Honchox.Conclusions.query/3` partial. |
| `scope.delete(conclusionId)` | `Honchox.ConclusionScope.delete(scope, conclusion_id)` | DELETE | `/v3/workspaces/{workspace_id}/conclusions/{conclusion_id}` | none | none | `:ok` | Existing `Honchox.Conclusions.delete/3` partial. |
| `scope.create(conclusion or conclusions)` | `Honchox.ConclusionScope.create(scope, conclusions)` | POST | `/v3/workspaces/{workspace_id}/conclusions` | none | `%{conclusions: [%{content, observer_id: scope.observer_id, observed_id: scope.observed_id, session_id: id_or_nil}]}` | `{:ok, [%Honchox.Conclusion{}]}` | Existing `Honchox.Conclusions.create/3` partial. TS accepts one or many and always returns array. |
| `scope.representation(options)` | `Honchox.ConclusionScope.representation(scope, opts \\ [])` | POST | `/v3/workspaces/{workspace_id}/peers/{observer_id}/representation` | none | `%{target: observed_id, search_query?: string, search_top_k?: integer, search_max_distance?: number, include_most_frequent?: boolean, max_conclusions?: integer}` | `{:ok, string}` | Current `Honchox.Conclusions.representation/2` is not SDK-equivalent and should be removed or made private. |
| `Conclusion.fromApiResponse(data)` | internal `Honchox.Conclusion.from_api/1` | none | none | none | none | `%Honchox.Conclusion{}` | Fields: `id`, `content`, `observer_id`, `observed_id`, `session_id`, `created_at`. |

## Context, representation, and LLM conversion functions

| TypeScript method | Target Elixir function | HTTP method | Path | Query params | Body shape | Return value | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `PeerContext.fromApiResponse(response)` | `Honchox.PeerContext.from_api/1` | none | none | none | none | `%Honchox.PeerContext{}` | Explicitly map `peer_id`, `target_id`, `representation`, `peer_card`. |
| `SessionContext.fromApiResponse(sessionId, data)` | `Honchox.SessionContext.from_api(session_id, data)` | none | none | none | none | `%Honchox.SessionContext{}` | Convert `messages` to `%Honchox.Message{}`, `summary` to `%Honchox.Summary{}`. |
| `ctx.toOpenAI(assistant)` | `Honchox.SessionContext.to_open_ai(ctx, assistant)` | none | none | none | none | `[%{role: string, content: string, name?: string}]` | Assistant peer messages become `%{role: "assistant", name: peer_id, content: content}`; others become `user`. Prepend system messages for `<peer_representation>...</peer_representation>`, `<peer_card>...</peer_card>`, and `<summary>...</summary>` when present. |
| `ctx.toAnthropic(assistant)` | `Honchox.SessionContext.to_anthropic(ctx, assistant)` | none | none | none | none | `[%{role: string, content: string}]` | Assistant peer messages become `%{role: "assistant", content: content}`; others become `%{role: "user", content: "#{peer_id}: #{content}"}`. Prepend user-role representation/card/summary XML blocks when present. |
| `SessionSummaries.fromApiResponse(data)` | `Honchox.SessionSummaries.from_api/1` | none | none | none | none | `%Honchox.SessionSummaries{}` | Fields: `id`, `short_summary`, `long_summary`; expose `session_id` alias if desired. |
| `Summary.fromApiResponse(data)` | `Honchox.Summary.from_api/1` | none | none | none | none | `%Honchox.Summary{}` | Fields: `content`, `message_id`, `summary_type`, `created_at`, `token_count`. |
| `Message.fromApiResponse(data)` | `Honchox.Message.from_api/1` | none | none | none | none | `%Honchox.Message{}` | Fields: `id`, `content`, `peer_id`, `session_id`, `workspace_id`, `metadata`, `created_at`, `token_count`. |

## Pagination and option shapes

| TypeScript behavior | Target Elixir behavior | HTTP/query/body impact | Notes |
| --- | --- | --- | --- |
| `Page<T>` current-page access: `items`, `total`, `page`, `size`, `pages` | `%Honchox.Page{items, total, page, size, pages}` | none | Pending. |
| `Page.getNextPage()` and async iteration | `Honchox.Page.next_page(page)` or no direct equivalent | Requires stored fetch function/client if supported | Pending design. Simpler first implementation can expose metadata only. |
| List options accept either raw `filters` or `{filters,page,size,reverse}` | Elixir opts: `filters: map, page: int, size: int, reverse: bool` | `filters` in body; page/size/reverse in query | Legacy raw filters not necessary unless intentionally supported. |
| `reverse` query | string `"true"` only when true | query parameter | Do not send false unless API expects it. |
| `searchQuery` accepts string or object with `content` | Elixir accepts binary or `%Honchox.Message{content: content}` | sent as `search_query` | Applies to representation options. |
| IDs can be strings or resource objects | Elixir accepts binaries or structs | sent as `*_id` strings | Resolve `%Honchox.Peer{id: id}` / `%Honchox.Session{id: id}`. |

## Configuration translation

| SDK config | Elixir option shape | Wire shape | Applies to |
| --- | --- | --- | --- |
| `PeerConfig.observeMe` | `observe_me` | `observe_me` | peer create/update |
| `SessionPeerConfig.observeMe` | `observe_me` | `observe_me` | session peer config |
| `SessionPeerConfig.observeOthers` | `observe_others` | `observe_others` | session peer config |
| `ReasoningConfig.customInstructions` | `custom_instructions` | `custom_instructions` | workspace/session/message config |
| `PeerCardConfig` | `peer_card: %{use:, create:}` | `peer_card` | workspace/session config |
| `SummaryConfig.messagesPerShortSummary` | `messages_per_short_summary` | `messages_per_short_summary` | workspace/session config |
| `SummaryConfig.messagesPerLongSummary` | `messages_per_long_summary` | `messages_per_long_summary` | workspace/session config |
| `DreamConfig.enabled` | `dream: %{enabled: ...}` | `dream.enabled` | workspace/session config |

## Existing Honchox APIs not present in TypeScript SDK

| Honchox API | Decision | Reason |
| --- | --- | --- |
| `Honchox.Keys.create/2`, `create_client/2` | Pending / likely keep only if documented separately | Not part of `@honcho-ai/sdk` public surface inspected for parity. |
| `Honchox.Observations` | Remove or keep deprecated aliases privately | TS SDK uses `Conclusion` / `ConclusionScope`; observations file exists only as compatibility/deprecation. |
| `Honchox.PeerWorkspaceQA.ask/4` | Remove from SDK parity surface or move to extension | Proprietary/non-SDK concept. |
| Low-level `Honchox.get/post/put/patch/delete/upload` | Move under `Honchox.HTTP` or keep internal | TS exposes `honcho.http` for advanced usage, but SDK public workflow should not be raw-map-first. |
| `Honchox.Conclusions.representation/2` current endpoint | Remove/rewrite | SDK representation is peer-scoped (`/peers/{peer_id}/representation`), not `/conclusions/representation`. |
| `Honchox.Sessions.representation/4` current endpoint | Rewrite | SDK uses peer representation endpoint with `session_id` in body. |

## Acceptance checklist for later implementation tasks

- [ ] Client defaults match TypeScript SDK (`https://api.honcho.dev`, `HONCHO_*` fallbacks, `workspace_id` default `default`).
- [ ] Every public SDK method above has an Elixir equivalent or an explicit documented omission.
- [ ] Context methods are implemented and tested: `Peer.context/2`, `Session.context/2`, `SessionContext.to_open_ai/2`, `SessionContext.to_anthropic/2`.
- [ ] Streaming chat has a public `chat_stream` plan/API before release, even if implemented later.
- [ ] Current raw-map modules are either rewritten to struct methods or moved under internal API modules.
