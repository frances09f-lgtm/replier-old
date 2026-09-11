# Requirements Document

## Introduction

This document specifies the requirements for adding Qwen 3 1.7B model support to the Auto-Reply Assistant's local AI service. The feature will extend the existing MODEL_REGISTRY to include the new Qwen 3 1.7B model as an additional option alongside the current Phi-3.5 Mini (3.8B) and Qwen2.5 1.5B models. The implementation will follow the established patterns for model configuration, downloading, loading, and inference using GGUF format models from HuggingFace.

## Glossary

- **PhiLocalService**: The Kotlin service class that manages local AI model operations, including model registry, downloading, loading, and inference
- **MODEL_REGISTRY**: A map data structure containing ModelConfig entries for all supported AI models
- **ModelConfig**: A data class defining model metadata including id, displayName, filename, download URL, size, description, threads, and context size
- **GGUF**: A file format for storing large language model weights, used by llama.cpp-based inference engines
- **HuggingFace**: A platform hosting machine learning models, used as the download source for model files
- **Qwen_3_1.7B**: The new Qwen 3 1.7B Instruct model to be added to the system
- **Inference_Engine**: The underlying llama.cpp-based engine that loads and runs the models
- **Model_Prompt_Format**: The specific chat template format required by a model (e.g., `<|im_start|>` for Qwen models, `<|system|>` for Phi models)

## Requirements

### Requirement 1: Model Registry Configuration

**User Story:** As a developer, I want to configure Qwen 3 1.7B in the model registry, so that the system recognizes and can manage this model.

#### Acceptance Criteria

1. THE PhiLocalService SHALL add a new ModelConfig entry to MODEL_REGISTRY with id "qwen_3_1_7b"
2. THE ModelConfig entry SHALL specify displayName as "Qwen 3 1.7B Instruct"
3. THE ModelConfig entry SHALL specify filename as "qwen-3-1.7b-instruct-q4_k_m.gguf"
4. THE ModelConfig entry SHALL specify a valid HuggingFace download URL for the Qwen 3 1.7B Q4_K_M quantized GGUF file
5. THE ModelConfig entry SHALL specify sizeBytes matching the actual file size of the model (approximately 1,100,000,000 bytes)
6. THE ModelConfig entry SHALL specify an appropriate description indicating model size and characteristics
7. THE ModelConfig entry SHALL specify threads value of 4 for optimal performance
8. THE ModelConfig entry SHALL specify contextSize value of 4096 tokens

### Requirement 2: Model Download Support

**User Story:** As a user, I want to download the Qwen 3 1.7B model, so that I can use it for generating auto-replies.

#### Acceptance Criteria

1. WHEN downloadModel is called with modelId "qwen_3_1_7b", THE PhiLocalService SHALL retrieve the ModelConfig for Qwen 3 1.7B from MODEL_REGISTRY
2. WHEN the Qwen 3 1.7B model is being downloaded, THE PhiLocalService SHALL report download progress from 0 to 100 percent
3. WHEN the Qwen 3 1.7B model download completes successfully, THE PhiLocalService SHALL save the file using the configured filename
4. WHEN the Qwen 3 1.7B model file exists and has size greater than half the configured sizeBytes, THE isModelAvailable function SHALL return true for "qwen_3_1_7b"
5. IF the Qwen 3 1.7B model download fails, THEN THE PhiLocalService SHALL delete any partial download files
6. IF the Qwen 3 1.7B model download fails, THEN THE PhiLocalService SHALL invoke the onComplete callback with success false and an error message

### Requirement 3: Model Loading Support

**User Story:** As a system, I want to load the Qwen 3 1.7B model into memory, so that it can be used for inference operations.

#### Acceptance Criteria

1. WHEN loadModel is called with modelId "qwen_3_1_7b", THE PhiLocalService SHALL verify the model file exists before loading
2. WHEN loading the Qwen 3 1.7B model, THE PhiLocalService SHALL use the configured contextSize of 4096 tokens
3. WHEN loading the Qwen 3 1.7B model, THE PhiLocalService SHALL use the configured threads value of 4
4. WHEN the Qwen 3 1.7B model loads successfully, THE PhiLocalService SHALL store the loaded model in the loadedModels cache with key "qwen_3_1_7b"
5. WHEN the Qwen 3 1.7B model loads successfully, THE PhiLocalService SHALL return a valid LlamaModel instance
6. IF the Qwen 3 1.7B model file does not exist, THEN THE loadModel function SHALL return null and log a warning
7. IF the Qwen 3 1.7B model loading fails with an exception, THEN THE loadModel function SHALL return null and log the error

### Requirement 4: Prompt Format Support

**User Story:** As a system, I want to format prompts correctly for Qwen 3 1.7B, so that the model generates appropriate responses.

#### Acceptance Criteria

1. WHEN building a prompt for modelId "qwen_3_1_7b", THE buildPrompt function SHALL detect the model as a Qwen variant
2. WHEN building a prompt for Qwen 3 1.7B, THE buildPrompt function SHALL use the Qwen chat template format with `<|im_start|>` and `<|im_end|>` tokens
3. WHEN building a prompt for Qwen 3 1.7B, THE buildPrompt function SHALL format the system prompt as `<|im_start|>system\n{prompt}<|im_end|>\n`
4. WHEN building a prompt for Qwen 3 1.7B with conversation history, THE buildPrompt function SHALL format user messages as `<|im_start|>user\n{content}<|im_end|>\n`
5. WHEN building a prompt for Qwen 3 1.7B with conversation history, THE buildPrompt function SHALL format assistant messages as `<|im_start|>assistant\n{content}<|im_end|>\n`
6. WHEN building a prompt for Qwen 3 1.7B, THE buildPrompt function SHALL format the incoming message as `<|im_start|>user\n{message}<|im_end|>\n`
7. WHEN building a prompt for Qwen 3 1.7B, THE buildPrompt function SHALL end the prompt with `<|im_start|>assistant\n` to signal the model to generate a response

### Requirement 5: Inference and Response Generation

**User Story:** As a user, I want to generate auto-replies using Qwen 3 1.7B, so that I can respond to messages with AI-generated content.

#### Acceptance Criteria

1. WHEN getAiReply is called with modelId "qwen_3_1_7b", THE PhiLocalService SHALL check if the model is available
2. WHEN generating a reply with Qwen 3 1.7B, THE PhiLocalService SHALL load the model if not already loaded
3. WHEN generating a reply with Qwen 3 1.7B, THE PhiLocalService SHALL build a properly formatted prompt using the Qwen chat template
4. WHEN generating a reply with Qwen 3 1.7B, THE PhiLocalService SHALL invoke the Inference_Engine with the loaded model and formatted prompt
5. WHEN generating a reply with Qwen 3 1.7B, THE PhiLocalService SHALL limit generation to 100 tokens maximum
6. WHEN generating a reply with Qwen 3 1.7B, THE PhiLocalService SHALL apply a 60-second timeout to inference operations
7. WHEN Qwen 3 1.7B inference completes successfully, THE PhiLocalService SHALL post-process the response to remove special tokens
8. WHEN Qwen 3 1.7B inference produces a valid response, THE PhiLocalService SHALL invoke the callback with the cleaned response text and usage statistics
9. IF Qwen 3 1.7B is not available, THEN THE PhiLocalService SHALL invoke the callback with a random fallback reply and an error indicating "Model not downloaded"
10. IF Qwen 3 1.7B inference times out, THEN THE PhiLocalService SHALL invoke the callback with a random fallback reply and an error indicating "Inference timed out"
11. IF Qwen 3 1.7B inference fails with an exception, THEN THE PhiLocalService SHALL invoke the callback with a random fallback reply and the exception message

### Requirement 6: Model Management Operations

**User Story:** As a user, I want to manage the Qwen 3 1.7B model, so that I can check its status and delete it when needed.

#### Acceptance Criteria

1. WHEN getModelConfig is called with modelId "qwen_3_1_7b", THE PhiLocalService SHALL return the corresponding ModelConfig from MODEL_REGISTRY
2. WHEN isModelAvailable is called with modelId "qwen_3_1_7b", THE PhiLocalService SHALL check if the model file exists and has valid size
3. WHEN isDownloading is called with modelId "qwen_3_1_7b", THE PhiLocalService SHALL return true if a download is in progress for this model
4. WHEN getDownloadProgress is called with modelId "qwen_3_1_7b", THE PhiLocalService SHALL return the current download progress percentage (0-100)
5. WHEN deleteModel is called with modelId "qwen_3_1_7b", THE PhiLocalService SHALL release the loaded model from memory if loaded
6. WHEN deleteModel is called with modelId "qwen_3_1_7b", THE PhiLocalService SHALL delete the model file from storage
