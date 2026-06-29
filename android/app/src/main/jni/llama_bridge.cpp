#include <jni.h>
#include <string>
#include <vector>
#include <mutex>
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <sys/stat.h>
#include <android/log.h>

#define LOG_TAG "LlamaBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#include "llama.h"

static JavaVM *g_jvm = nullptr;

static struct {
    llama_model *model = nullptr;
    llama_context *ctx = nullptr;
    const llama_vocab *vocab = nullptr;
    std::mutex mutex;
} g_state;

static jboolean nativeLoadModel(JNIEnv*, jobject, jstring);
static jstring nativeGenerate(JNIEnv*, jobject, jstring, jstring, jstring, jint, jfloat);
static void nativeUnloadModel(JNIEnv*, jobject);

extern "C" JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM *vm, void *) {
    g_jvm = vm;
    JNIEnv *env;
    if (vm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK) return JNI_ERR;

    jclass cls = env->FindClass("com/example/auto_reply_assistant/service/LocalAiService");
    if (!cls) {
        LOGE("JNI_OnLoad: failed to find LocalAiService class");
        return JNI_ERR;
    }

    JNINativeMethod methods[] = {
        {"nativeLoadModel",   "(Ljava/lang/String;)Z", (void*)&nativeLoadModel},
        {"nativeGenerate",    "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;IF)Ljava/lang/String;", (void*)&nativeGenerate},
        {"nativeUnloadModel", "()V",                    (void*)&nativeUnloadModel},
    };

    if (env->RegisterNatives(cls, methods, 3) < 0) {
        LOGE("JNI_OnLoad: failed to register natives");
        return JNI_ERR;
    }

    LOGI("JNI_OnLoad: registered 3 native methods");
    env->DeleteLocalRef(cls);
    return JNI_VERSION_1_6;
}

static std::vector<llama_token> tokenize(const llama_vocab *vocab, const std::string &text, bool add_special) {
    LOGI("tokenize: text_len=%zu add_special=%d", text.length(), add_special);

    // Query buffer size: llama_tokenize returns -(required) when n_tokens_max < actual
    int n_tokens = llama_tokenize(vocab, text.c_str(), (int)text.length(), nullptr, 0, add_special, true);
    if (n_tokens < 0) {
        n_tokens = -n_tokens;
    }
    if (n_tokens == 0) {
        LOGE("tokenize: zero tokens from model");
        return {};
    }
    std::vector<llama_token> result(n_tokens);
    int n = llama_tokenize(vocab, text.c_str(), (int)text.length(), result.data(), (int)result.size(), add_special, true);
    if (n < 0) {
        n = llama_tokenize(vocab, text.c_str(), (int)text.length(), result.data(), (int)result.size(), add_special, false);
    }
    if (n < 0) {
        n = llama_tokenize(vocab, text.c_str(), (int)text.length(), result.data(), (int)result.size(), false, false);
    }
    if (n < 0) { LOGE("tokenize: all attempts failed, last error: %d", n); return {}; }
    result.resize(n);
    LOGI("tokenize: success, %zu tokens", result.size());
    return result;
}

static std::string token_to_piece(const llama_vocab *vocab, llama_token token) {
    std::vector<char> buf(8);
    int n = llama_token_to_piece(vocab, token, buf.data(), (int)buf.size(), 0, false);
    if (n < 0) {
        buf.resize(-n);
        n = llama_token_to_piece(vocab, token, buf.data(), (int)buf.size(), 0, false);
    }
    return std::string(buf.data(), (size_t)n);
}

struct SamplerContext {
    llama_sampler * chain = nullptr;
    bool initialized = false;
    float lastTemperature = 0.0f;

    ~SamplerContext() {
        if (chain) llama_sampler_free(chain);
    }

    void init(float temperature) {
        if (!initialized || temperature != lastTemperature) {
            if (chain) llama_sampler_free(chain);
            auto sparams = llama_sampler_chain_default_params();
            chain = llama_sampler_chain_init(sparams);
            llama_sampler_chain_add(chain, llama_sampler_init_top_k(40));
            llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.9f, 1));
            llama_sampler_chain_add(chain, llama_sampler_init_temp(temperature));
            llama_sampler_chain_add(chain, llama_sampler_init_dist(0));
            initialized = true;
            lastTemperature = temperature;
        }
    }
};

static SamplerContext g_sampler;

static bool decode_batch(llama_context *ctx, llama_token *tokens, int32_t n_tokens, int32_t n_past) {
    llama_batch batch = llama_batch_init(n_tokens, 0, 1);
    if (batch.token == nullptr) {
        LOGE("Failed to allocate batch for %d tokens", n_tokens);
        return false;
    }

    for (int32_t i = 0; i < n_tokens; i++) {
        batch.token[i]    = tokens[i];
        batch.pos[i]      = n_past + i;
        batch.n_seq_id[i] = 1;
        batch.seq_id[i][0] = 0;
        batch.logits[i]   = (i == n_tokens - 1) ? 1 : 0;
    }
    batch.n_tokens = n_tokens;

    int rc = llama_decode(ctx, batch);
    llama_batch_free(batch);
    return rc == 0;
}

static jboolean
nativeLoadModel(JNIEnv *env, jobject, jstring model_path) {

    const char *path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Loading model from: %s", path);

    struct stat st;
    if (stat(path, &st) != 0) {
        LOGE("Model file not found or not accessible: %s", path);
        env->ReleaseStringUTFChars(model_path, path);
        return JNI_FALSE;
    }
    if (st.st_size < 1024 * 1024) {
        LOGE("Model file too small (%ld bytes) - likely corrupted or incomplete download", (long)st.st_size);
        env->ReleaseStringUTFChars(model_path, path);
        return JNI_FALSE;
    }
    LOGI("Model file size: %ld bytes", (long)st.st_size);

    std::lock_guard<std::mutex> lock(g_state.mutex);

    if (g_state.model != nullptr) {
        LOGI("Unloading previous model");
        if (g_state.ctx) { llama_free(g_state.ctx); g_state.ctx = nullptr; }
        if (g_state.model) { llama_model_free(g_state.model); g_state.model = nullptr; }
        g_state.vocab = nullptr;
    }

    llama_backend_init();

    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;

    g_state.model = llama_model_load_from_file(path, model_params);
    env->ReleaseStringUTFChars(model_path, path);

    if (g_state.model == nullptr) {
        LOGE("Failed to load model");
        llama_backend_free();
        return JNI_FALSE;
    }

    g_state.vocab = llama_model_get_vocab(g_state.model);
    if (g_state.vocab == nullptr) {
        LOGE("Failed to get vocab from model");
        llama_model_free(g_state.model);
        g_state.model = nullptr;
        llama_backend_free();
        return JNI_FALSE;
    }

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 1024;
    ctx_params.n_batch = 512;
    ctx_params.n_threads = 4;
    ctx_params.n_threads_batch = 4;

    g_state.ctx = llama_init_from_model(g_state.model, ctx_params);
    if (g_state.ctx == nullptr) {
        LOGE("Failed to create context");
        llama_model_free(g_state.model);
        g_state.model = nullptr;
        g_state.vocab = nullptr;
        llama_backend_free();
        return JNI_FALSE;
    }

    LOGI("Model loaded successfully (n_ctx=%d)", (int)llama_n_ctx(g_state.ctx));
    return JNI_TRUE;
}

static jstring
nativeGenerate(JNIEnv *env, jobject, jstring system_prompt, jstring sender_name, jstring incoming_message, jint max_tokens, jfloat temperature) {

    const char *sys_str = env->GetStringUTFChars(system_prompt, nullptr);
    const char *sender_str = env->GetStringUTFChars(sender_name, nullptr);
    const char *msg_str = env->GetStringUTFChars(incoming_message, nullptr);

    std::string sys(sys_str);
    std::string sender(sender_str);
    std::string message(msg_str);

    env->ReleaseStringUTFChars(system_prompt, sys_str);
    env->ReleaseStringUTFChars(sender_name, sender_str);
    env->ReleaseStringUTFChars(incoming_message, msg_str);

    // Build prompt using model's chat template
    std::string user_msg = "Message from " + sender + ": " + message;
    llama_chat_message chat[] = {
        {"system", sys.c_str()},
        {"user",   user_msg.c_str()},
    };

    const char *tmpl = llama_model_chat_template(g_state.model);
    int32_t fmt_len = llama_chat_apply_template(tmpl, chat, 2, true, nullptr, 0);
    std::vector<char> fmt_buf(fmt_len > 0 ? fmt_len : 2048);
    fmt_len = llama_chat_apply_template(tmpl, chat, 2, true, fmt_buf.data(), (int32_t)fmt_buf.size());
    std::string prompt_cpp(fmt_buf.data(), fmt_len > 0 ? (size_t)fmt_len : 0);

    if (prompt_cpp.empty()) {
        prompt_cpp = sys + "\n\nMessage from " + sender + ": " + message + "\n\nYour reply:";
    }

    LOGI("Generating (prompt_len=%zu, max_tokens=%d)", prompt_cpp.length(), max_tokens);

    std::lock_guard<std::mutex> lock(g_state.mutex);

    if (g_state.model == nullptr || g_state.ctx == nullptr || g_state.vocab == nullptr) {
        LOGE("Model not loaded");
        return env->NewStringUTF("");
    }

    // Clear KV cache to prevent interference between generations
    llama_kv_cache_clear(g_state.ctx);

    auto tokens = tokenize(g_state.vocab, prompt_cpp, false);
    if (tokens.empty()) {
        LOGE("Tokenization failed");
        return env->NewStringUTF("");
    }

    int n_ctx = (int)llama_n_ctx(g_state.ctx);

    // Cap max_tokens to leave room for prompt
    if (max_tokens > n_ctx / 2) {
        max_tokens = n_ctx / 2;
    }

    if ((int)tokens.size() + max_tokens > n_ctx) {
        int keep = n_ctx - max_tokens;
        if (keep < 1) keep = 1;
        int skip = (int)tokens.size() - keep;
        std::vector<llama_token> kept(keep);
        std::copy(tokens.begin() + skip, tokens.end(), kept.begin());
        tokens = std::move(kept);
        LOGI("Truncated prompt to %d tokens (dropped %d from start)", keep, skip);
    }

    // Emergency: if prompt is still too large, hard-cap at 80% of context
    int max_prompt = (int)(n_ctx * 0.8);
    if ((int)tokens.size() > max_prompt) {
        tokens.resize(max_prompt);
        LOGI("Emergency truncation to %d tokens", max_prompt);
    }

    int n_past = 0;
    std::string result;

    LOGI("Decoding prompt (%zu tokens)...", tokens.size());

    // Decode prompt in small chunks to avoid overwhelming the CPU
    const int32_t batch_size = 64;
    for (size_t pos = 0; pos < tokens.size(); pos += batch_size) {
        size_t chunk = std::min((size_t)batch_size, tokens.size() - pos);
        LOGI("Decoding chunk at pos %zu, size %zu", pos, chunk);
        if (!decode_batch(g_state.ctx, tokens.data() + pos, (int)chunk, n_past)) {
            LOGE("llama_decode failed on prompt at pos %zu", pos);
            return env->NewStringUTF("");
        }
        n_past += (int)chunk;
    }
    LOGI("Prompt decoded (%d tokens)", n_past);

    float temp = temperature > 0.0f ? temperature : 0.7f;
    g_sampler.init(temp);

    for (int i = 0; i < max_tokens; i++) {
        llama_token id = llama_sampler_sample(g_sampler.chain, g_state.ctx, -1);

        if (llama_vocab_is_eog(g_state.vocab, id)) {
            LOGI("EOG token at step %d", i);
            break;
        }

        std::string piece = token_to_piece(g_state.vocab, id);
        result += piece;
        if (result.size() > 128) break;

        if (!decode_batch(g_state.ctx, &id, 1, n_past)) {
            LOGE("decode failed at token %d", i);
            break;
        }
        n_past += 1;
    }

    LOGI("Generated %zu chars", result.size());
    return env->NewStringUTF(result.c_str());
}

static void
nativeUnloadModel(JNIEnv *env, jobject) {

    std::lock_guard<std::mutex> lock(g_state.mutex);
    LOGI("Unloading model");

    if (g_state.ctx) { llama_free(g_state.ctx); g_state.ctx = nullptr; }
    if (g_state.model) { llama_model_free(g_state.model); g_state.model = nullptr; }
    g_state.vocab = nullptr;

    llama_backend_free();
    LOGI("Model unloaded");
}
