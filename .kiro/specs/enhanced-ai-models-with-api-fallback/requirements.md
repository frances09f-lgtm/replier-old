# Requirements Document: Enhanced AI Models with API Fallback

## Introduction

This document specifies the requirements for improving the Auto-Reply Assistant's AI model strategy. The feature will:
- Remove the underperforming Phi model
- Keep and retain Qwen2.5 1.5B as a primary local model
- Add Indra model for Marathi language support
- Add Cerebras API integration with user-configurable API key
- Implement intelligent fallback logic: use local models first, fall back to Cerebras API for complex/confusing messages

## Glossary

- **PhiLocalService**: The Kotlin service class that manages local and remote AI model operations
- **MODEL_REGISTRY**: A map data structure containing ModelConfig entries for all supported AI models
- **ModelConfig**: A data class defining model metadata including id, displayName, filename, download URL, size, description
- **Indra Model**: A multilingual model supporting Marathi language and other Indian languages
- **Cerebras API**: A cloud-based API service for advanced language model inference
- **API Key**: User-provided authentication token for Cerebras API access
- **Local Model**: GGUF format models running inference locally on device
- **Complexity Detection**: Algorithm to determine if a message is too complex for local model processing
- **Fallback Strategy**: Logic to automatically use API when local model confidence is low
- **GGUF**: File format for storing large language model weights

## Requirements

### Requirement 1: Remove Phi Model from Registry

**User Story:** As a developer, I want to remove the Phi model from the model registry, so that only useful models are available to users.

#### Acceptance Criteria

1. THE PhiLocalService SHALL remove the "phi_3_5_mini" entry from MODEL_REGISTRY
2. WHEN the app starts, THE Phi model SHALL NOT be available in model selection UI
3. THE existing Phi model files on user devices SHALL NOT be deleted (users can manage themselves)
4. WHEN existing code references Phi model, THEN the system SHALL handle the missing model gracefully with an error message

### Requirement 2: Retain Qwen2.5 1.5B Model

**User Story:** As a user, I want to continue using Qwen2.5 1.5B, so that I have a reliable local model.

#### Acceptance Criteria

1. THE Qwen2.5 1.5B model entry SHALL remain in MODEL_REGISTRY unchanged
2. THE existing Qwen2.5 configuration and download URL SHALL remain the same
3. THE Qwen2.5 inference logic and prompt formatting SHALL remain unchanged
4. WHEN Qwen2.5 is selected, THE system SHALL use local inference as primary method

### Requirement 3: Indra Model Configuration and Support

**User Story:** As a user speaking Marathi, I want to use a local model that understands Marathi language, so that auto-replies can be generated in my language.

#### Acceptance Criteria

1. THE PhiLocalService SHALL add a new ModelConfig entry to MODEL_REGISTRY with id "indra_model"
2. THE ModelConfig entry SHALL specify displayName as "Indra Model (Multilingual + Marathi)"
3. THE ModelConfig entry SHALL specify filename as "indra-instruct-q4_k_m.gguf"
4. THE ModelConfig entry SHALL specify a valid download URL for Indra model from HuggingFace
5. THE ModelConfig entry SHALL specify sizeBytes approximately 2,500,000,000 bytes (for a 2.5GB quantized model)
6. THE ModelConfig entry SHALL specify an appropriate description indicating Marathi/multilingual support
7. THE ModelConfig entry SHALL specify threads value of 4 for optimal performance
8. THE ModelConfig entry SHALL specify contextSize value of 4096 tokens
9. WHEN loading Indra model for Marathi messages, THE system SHALL detect the language and apply language-specific prompt formatting
10. WHEN building a prompt for Indra, THE buildPrompt function SHALL use appropriate chat template format (Qwen-style `<|im_start|>` tokens)

### Requirement 4: Cerebras API Integration

**User Story:** As a user, I want to optionally configure a Cerebras API key, so that I can use cloud-based AI for complex queries when local models struggle.

#### Acceptance Criteria

1. THE PhiLocalService SHALL add a CerebrasApiConfig data class containing apiKey field
2. THE PhiLocalService SHALL add configuration storage/retrieval methods for Cerebras API key
3. THE PhiLocalService SHALL add a ModelConfig entry for Cerebras with id "cerebras_api"
4. WHEN Cerebras API key is empty or blank, THE system SHALL treat Cerebras as unavailable
5. THE app's settings UI SHALL provide a text input field to configure Cerebras API key securely
6. WHEN user provides a Cerebras API key, THE key SHALL be validated before saving (optional lightweight check)
7. WHEN user clears the API key, THE system SHALL fall back to local models only
8. THE Cerebras API configuration SHALL be persisted across app restarts

### Requirement 5: Complexity Detection Algorithm

**User Story:** As a system, I want to automatically detect complex or confusing messages, so that challenging queries can be routed to the cloud API.

#### Acceptance Criteria

1. THE PhiLocalService SHALL implement a detectComplexity function that analyzes incoming messages
2. THE detectComplexity function SHALL return a complexity score from 0 to 100 (0=simple, 100=very complex)
3. WHEN detecting complexity, THE system SHALL analyze:
   - Message length (longer messages are more complex)
   - Vocabulary diversity (varied vocabulary = more complex)
   - Special characters and punctuation patterns
   - Presence of technical terms or domain-specific language
   - Question count (multiple questions = more complex)
   - Language mixing (code blocks, mixed languages)
4. WHEN complexity score is >= 70, THE message is considered complex
5. WHEN complexity score is < 70, THE message is considered simple
6. WHEN message contains specific keywords indicating technical/professional context, THE complexity score SHALL increase by 20
7. THE detectComplexity function SHALL run quickly (< 100ms) on any message

### Requirement 6: Fallback Strategy - Local First with API Backup

**User Story:** As a system, I want to intelligently route messages to local or cloud models, so that users get fast responses while maintaining quality for complex queries.

#### Acceptance Criteria

1. WHEN getAiReply is called with a primary local modelId (Qwen or Indra), THE system SHALL first attempt local inference
2. WHEN local model inference succeeds, THE system SHALL return the local response immediately
3. WHEN local model inference fails OR message complexity >= 70 AND Cerebras API key is configured, THE system SHALL automatically attempt Cerebras API
4. WHEN attempting Cerebras API fallback, THE system SHALL send the message to Cerebras with the configured API key
5. IF Cerebras API succeeds, THE system SHALL return the API response with metadata indicating API usage
6. IF Cerebras API also fails OR no API key configured, THE system SHALL return a fallback reply
7. WHEN both local and API fail, THE system SHALL log both errors and return a generic fallback reply
8. THE fallback strategy SHALL NOT block user interaction (async operation with timeout)
9. WHEN Cerebras API is used, THE response SHALL include usage information indicating "api_fallback" source

### Requirement 7: Cerebras API Communication

**User Story:** As a system, I want to communicate with Cerebras API, so that I can leverage cloud-based model inference.

#### Acceptance Criteria

1. THE PhiLocalService SHALL implement sendToCerebrasApi function for API calls
2. WHEN calling Cerebras API, THE system SHALL use HTTPS with proper SSL/TLS
3. THE Cerebras API request SHALL include:
   - The user's API key in Authorization header
   - The incoming message as user content
   - Appropriate system prompt for auto-reply generation
   - Conversation history if available (last 5 messages max)
   - Max tokens parameter (100 for consistent response length)
4. THE Cerebras API response parsing SHALL handle:
   - Successful responses with generated text
   - Rate limit errors (429)
   - Authentication errors (401, 403)
   - Server errors (500+)
   - Network timeouts (15-second timeout recommended)
5. WHEN Cerebras API returns an error, THE system SHALL log the error and attempt local fallback
6. WHEN Cerebras API succeeds, THE response text SHALL be post-processed same as local responses
7. THE Cerebras integration SHALL support batch operations similar to local inference

### Requirement 8: Model Selection and Configuration UI

**User Story:** As a user, I want to easily select which AI model(s) to use and configure the API key, so that I can customize my auto-reply experience.

#### Acceptance Criteria

1. THE app's model selection screen SHALL display only non-removed models (Qwen, Indra)
2. THE model selection SHALL show model sizes, descriptions, and capabilities
3. WHEN a model is selected, THE app SHALL indicate if it needs download
4. THE app SHALL provide a Settings/Configuration section with:
   - Cerebras API key input field (masked for security)
   - Option to test API connection (validate API key)
   - Indicator showing current API connection status
   - Info text explaining local vs. API usage strategy
5. WHEN user enters an invalid API key format, THE app SHALL show a validation message
6. THE API key field SHALL be optional (users can use local models only)

### Requirement 9: Intelligent Model Selection Based on Language

**User Story:** As a user, I want the system to automatically suggest appropriate models based on message language, so that I get better responses.

#### Acceptance Criteria

1. THE system SHALL detect message language using simple heuristics or library
2. WHEN message is detected as Marathi, THE system SHALL prioritize Indra model if available
3. WHEN message is in English or mixed language, THE system SHALL use Qwen as primary
4. WHEN user has explicitly selected a model, THE system SHALL respect that choice over auto-detection
5. THE language detection SHALL not block message processing (< 50ms)

### Requirement 10: Error Handling and Fallback Strategy

**User Story:** As a user, I want the system to handle errors gracefully, so that auto-reply always works even if something fails.

#### Acceptance Criteria

1. IF local model is not downloaded, THE system SHALL show "Model needs download" and offer download option
2. IF local model inference fails, THE system SHALL automatically try Cerebras API (if configured)
3. IF both local and API fail, THE system SHALL return a generic fallback reply (e.g., "Thanks for your message!")
4. WHEN an inference operation times out, THE system SHALL return a fallback reply after max timeout
5. WHEN API key is invalid, THE system SHALL show a clear error message in logs and fall back to local model
6. ALL errors SHALL be logged with enough context for debugging
7. THE system SHALL NOT crash or hang due to inference failures

### Requirement 11: Performance Optimization

**User Story:** As a user, I want fast auto-replies, so that I don't experience noticeable delays.

#### Acceptance Criteria

1. LOCAL model inference SHALL timeout after 60 seconds
2. CEREBRAS API calls SHALL timeout after 15 seconds
3. THE complexity detection SHALL complete in < 100ms
4. WHEN using local model, THE response should arrive within 30-90 seconds (depending on device)
5. WHEN using Cerebras API, THE response should arrive within 15 seconds
6. THE system SHALL NOT load multiple models simultaneously (only active model in memory)
7. WHEN switching models, THE previous model SHALL be unloaded from memory

### Requirement 12: Logging and Monitoring

**User Story:** As a developer, I want to understand which models are being used, so that I can optimize the system.

#### Acceptance Criteria

1. EACH inference attempt SHALL log:
   - Model used (local or API)
   - Message complexity score
   - Success/failure status
   - Response time
   - Fallback reason (if any)
2. WHEN API is used, THE log SHALL indicate it was a fallback and the reason (complexity, local failure, etc.)
3. LOG entries SHALL include timestamp and modelId for easy filtering
4. WHEN configuration is loaded/saved, THE system SHALL log those events (without exposing actual API key)

## Design Considerations

- **Security**: API keys should never be logged in full; mask in logs
- **Performance**: Local inference is much faster than API, prioritize it
- **User Control**: Users should see when API is being used and why
- **Reliability**: Always have a fallback, even if just a generic reply
- **Language Support**: Indra model opens possibility for multi-language replies

## Out of Scope

- Implementing actual Cerebras API client library (can use HTTP client)
- Building the app UI (just provide backend APIs for settings)
- Machine learning for complexity detection (use simple heuristics)
- Caching API responses
- Cost tracking for API usage
