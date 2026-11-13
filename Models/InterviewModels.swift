import Foundation

// AI Interview Voice Coach — v1.1.0 build 3, bundle com.shaik.aiinterviewvoice
// Real human-voice interviewer + spoken answers + voice correction + English check
// + video body observation (posture / eye / movement, on-device Vision).
// On-device only: no server, no login, no upload. History stays on the phone.

enum Topic: String, CaseIterable, Codable, Identifiable {
    case all = "All Topics"
    case python = "Python"
    case sql = "SQL"
    case maths = "Maths for AI"
    case ml = "Machine Learning"
    case dl = "Deep Learning"
    case genai = "Generative AI"
    case agents = "AI Agents"
    case mlops = "MLOps"
    case coding = "Coding"
    case hr = "HR"
    var id: String { rawValue }
    var short: String {
        switch self {
        case .all: return "All"
        case .maths: return "Maths"
        case .ml: return "ML"
        case .dl: return "DL"
        case .genai: return "GenAI"
        default: return rawValue
        }
    }
}

enum Difficulty: String, Codable { case basic = "Basic"; case intermediate = "Intermediate" }

struct InterviewQuestion: Identifiable, Codable, Hashable {
    let id: Int
    let topic: Topic
    let difficulty: Difficulty
    let question: String
    let keywords: [String]
    let idealAnswer: String
    let tip: String
}

struct Evaluation: Codable, Identifiable {
    let id: UUID
    let questionId: Int
    let question: String
    let topic: String
    let transcript: String
    let date: Date
    let durationSeconds: Double
    let contentScore: Int
    let englishScore: Int
    let overallScore: Int
    let verdict: String
    let missingKeywords: [String]
    let fillerCount: Int
    let wordsPerMinute: Int
    let englishTips: [String]
    let correctedAnswer: String
    // v1.8: how much of the question the answer actually covered
    // (0.0–1.0). Optional so history saved by v1.7 and earlier still
    // decodes — those rows fall back to a content-score estimate.
    var keywordCoverage: Double? = nil
    // Video body observation (v1.1, optional so v1.0 history still decodes).
    var bodyScore: Int?
    var bodyPosture: String?
    var bodyEye: String?
    var bodyMovement: String?
    var bodyTips: [String]?
    /// v1.8 relevance: Relevant = most key ideas covered (high marks),
    /// Partly relevant = some ideas, Mostly irrelevant = barely any,
    /// Irrelevant = none of the key ideas at all (low marks).
    var relevanceLabel: String {
        let c: Double
        if let stored = keywordCoverage { c = stored }
        else if contentScore >= 70 { c = 0.7 }
        else if contentScore >= 40 { c = 0.45 }
        else if contentScore > 10 { c = 0.2 }
        else { c = 0 }
        switch c {
        case 0.6...: return "Relevant"
        case 0.34..<0.6: return "Partly relevant"
        case 0.0001..<0.34: return "Mostly irrelevant"
        default: return "Irrelevant"
        }
    }
    var isRelevant: Bool { relevanceLabel == "Relevant" }
    var isIrrelevant: Bool { relevanceLabel == "Irrelevant" || relevanceLabel == "Mostly irrelevant" }
    /// Attach a body-observation result to this evaluation.
    func withBody(_ result: BodyLanguageResult) -> Evaluation {
        var copy = self
        copy.bodyScore = result.bodyScore
        copy.bodyPosture = result.postureLabel
        copy.bodyEye = result.eyeLabel
        copy.bodyMovement = result.movementLabel
        copy.bodyTips = result.tips
        return copy
    }
    /// v1.2: ONE spoken correction script — answer correction + body tips
    /// in a single utterance. (v1.1 spoke the body tip with a second speak()
    /// call, which cancelled the answer correction mid-sentence.)
    func spokenCorrection() -> String {
        if overallScore >= 80 {
            var good = "Good answer. \(englishTips.first ?? "")"
            if let bs = bodyScore, bs < 70, let tips = bodyTips, !tips.isEmpty {
                good += " Body language: \(tips.prefix(2).joined(separator: " "))"
            }
            return good
        }
        // v1.8: say plainly when the answer was off-topic, then the
        // correct answer — the spoken script must match the on-screen
        // "Irrelevant" verdict.
        var script = isIrrelevant
            ? "That answer was off-topic. It did not cover the key ideas for this question. \(correctedAnswer)"
            : "Your answer was \(verdict). \(correctedAnswer)"
        if let bs = bodyScore, bs < 70, let tips = bodyTips, !tips.isEmpty {
            script += " Body language: \(tips.prefix(2).joined(separator: " "))"
        }
        return script
    }
    var overallLabel: String {
        switch overallScore { case 80...100: return "Strong — interview ready"
        case 60..<80: return "Good — polish a little"
        case 40..<60: return "Needs work"
        default: return "Needs practice" }
    }
}

enum InterviewMode: String, CaseIterable, Codable {
    case practice = "Practice"
    case mock = "Mock Interview (5 Qs)"
    // v1.7: Interview Prep — a full AI Engineer interview: the
    // classic HR questions first (tell me about yourself, strengths,
    // weakness, why hire you, five years, challenge), then the
    // technical bank (Python, ML, GenAI, Agents, ...), so he can
    // prepare for a real AI Engineer interview with the answer on
    // screen to read and practise.
    case prep = "Interview Prep (AI Engineer)"
    var count: Int { self == .mock ? 5 : 0 }
}

// MARK: - Full 63-question bank (from shaik's INTERVIEW_QUESTIONS.md, in English —
// the language interviewers actually ask in. Sample answers are the ideal answers
// the voice coach speaks back when an answer is wrong or partial.)
struct QuestionBank {
    static let all: [InterviewQuestion] = [
        // Python (1-7)
        InterviewQuestion(id: 1, topic: .python, difficulty: .basic, question: "What is a variable in Python? What happens when you write x = 10?",
            keywords: ["name", "reference", "value", "memory", "bind", "object"],
            idealAnswer: "A variable is a named reference to a value stored in memory. When I write x equals 10, the name x is bound to the integer object 10.",
            tip: "Start with the definition, then the example. One sentence each."),
        InterviewQuestion(id: 2, topic: .python, difficulty: .basic, question: "What is the difference between a list and a tuple?",
            keywords: ["mutable", "immutable", "change", "fixed", "list", "tuple"],
            idealAnswer: "A list is mutable, so I can change it after creation. A tuple is immutable, so its values are fixed once created.",
            tip: "Give the one-word contrast first: mutable versus immutable."),
        InterviewQuestion(id: 3, topic: .python, difficulty: .intermediate, question: "What is a function, and why do we use def?",
            keywords: ["reusable", "block", "parameters", "return", "def"],
            idealAnswer: "A function is a reusable block of code defined with def. It takes parameters, does some work, and can return a value.",
            tip: "Name the keyword def and what it does."),
        InterviewQuestion(id: 4, topic: .python, difficulty: .intermediate, question: "In OOP, what is the difference between a class and an object?",
            keywords: ["blueprint", "instance", "class", "object"],
            idealAnswer: "A class is a blueprint. An object is a concrete instance created from that blueprint.",
            tip: "Blueprint versus instance is the answer interviewers want."),
        InterviewQuestion(id: 5, topic: .python, difficulty: .intermediate, question: "What is a decorator? Give one example.",
            keywords: ["decorator", "function", "wrap", "extra behaviour", "@"],
            idealAnswer: "A decorator is a function that takes another function and returns a wrapped version with extra behaviour, applied with the at symbol.",
            tip: "Say what it takes in and what it returns."),
        InterviewQuestion(id: 6, topic: .python, difficulty: .intermediate, question: "Why do we use try-except in exception handling?",
            keywords: ["try", "except", "error", "recover", "crash"],
            idealAnswer: "Try-except catches runtime errors so the program can recover gracefully instead of crashing.",
            tip: "Mention recover instead of crash."),
        InterviewQuestion(id: 7, topic: .python, difficulty: .intermediate, question: "What is a generator? How is it different from a list?",
            keywords: ["generator", "yield", "one at a time", "memory", "list"],
            idealAnswer: "A generator yields values one at a time with yield, using very little memory, unlike a list which stores everything at once.",
            tip: "Contrast memory use: one at a time versus stored all at once."),
        // SQL (8-14)
        InterviewQuestion(id: 8, topic: .sql, difficulty: .basic, question: "What is SQL, and why do we use it in a database?",
            keywords: ["sql", "query", "manage", "relational", "database"],
            idealAnswer: "SQL is the language used to query and manage data stored in a relational database.",
            tip: "Query and manage are the two verbs to include."),
        InterviewQuestion(id: 9, topic: .sql, difficulty: .basic, question: "What does a SELECT statement do?",
            keywords: ["select", "retrieve", "columns", "rows", "table"],
            idealAnswer: "SELECT retrieves chosen columns and rows from a table.",
            tip: "Keep it to one sentence."),
        InterviewQuestion(id: 10, topic: .sql, difficulty: .intermediate, question: "What is the difference between WHERE and HAVING?",
            keywords: ["where", "having", "filter", "rows", "groups", "group by"],
            idealAnswer: "WHERE filters rows before grouping. HAVING filters groups after GROUP BY.",
            tip: "Before grouping versus after grouping is the whole answer."),
        InterviewQuestion(id: 11, topic: .sql, difficulty: .intermediate, question: "What is the difference between INNER JOIN and LEFT JOIN?",
            keywords: ["inner join", "left join", "matching", "all", "rows"],
            idealAnswer: "INNER JOIN returns only matching rows from both tables. LEFT JOIN returns all rows from the left table plus any matches.",
            tip: "Only matching versus all left rows."),
        InterviewQuestion(id: 12, topic: .sql, difficulty: .intermediate, question: "What is GROUP BY?",
            keywords: ["group by", "groups", "aggregate", "count", "sum"],
            idealAnswer: "GROUP BY groups rows that share a value, so aggregate functions like COUNT or SUM apply per group.",
            tip: "Give one aggregate example."),
        InterviewQuestion(id: 13, topic: .sql, difficulty: .intermediate, question: "What is a subquery?",
            keywords: ["subquery", "nested", "inside", "outer query"],
            idealAnswer: "A subquery is a query nested inside another query, whose result feeds the outer query.",
            tip: "Nested inside is the key phrase."),
        InterviewQuestion(id: 14, topic: .sql, difficulty: .intermediate, question: "Give one example of a window function.",
            keywords: ["window", "row_number", "partition by", "order by"],
            idealAnswer: "ROW NUMBER OVER PARTITION BY department ORDER BY salary DESC numbers rows inside each department by salary.",
            tip: "Name the function and what PARTITION BY does."),
        // Maths (15-20)
        InterviewQuestion(id: 15, topic: .maths, difficulty: .basic, question: "What is the mean, or average? How do you calculate it?",
            keywords: ["mean", "sum", "divide", "values"],
            idealAnswer: "The mean is the sum of the values divided by how many values there are.",
            tip: "State the formula in words."),
        InterviewQuestion(id: 16, topic: .maths, difficulty: .basic, question: "Explain probability in simple words.",
            keywords: ["probability", "likelihood", "event", "0", "1"],
            idealAnswer: "Probability is the likelihood of an event, measured between 0 for impossible and 1 for certain.",
            tip: "Give the 0 to 1 range."),
        InterviewQuestion(id: 17, topic: .maths, difficulty: .intermediate, question: "What is a vector, and why is it important in ML?",
            keywords: ["vector", "numbers", "magnitude", "direction", "features", "embeddings"],
            idealAnswer: "A vector is an ordered list of numbers with magnitude and direction. In ML it represents features or embeddings.",
            tip: "Link it to features or embeddings."),
        InterviewQuestion(id: 18, topic: .maths, difficulty: .intermediate, question: "What is a derivative?",
            keywords: ["derivative", "rate", "change", "slope"],
            idealAnswer: "A derivative measures how fast a function's output changes when its input changes — the slope at a point.",
            tip: "Slope is the word interviewers listen for."),
        InterviewQuestion(id: 19, topic: .maths, difficulty: .intermediate, question: "What is a gradient, and how is it used in gradient descent?",
            keywords: ["gradient", "steepest", "increase", "descent", "minimize", "loss"],
            idealAnswer: "The gradient points in the direction of steepest increase. Gradient descent steps in the opposite direction to minimise the loss.",
            tip: "Opposite direction is the key idea."),
        InterviewQuestion(id: 20, topic: .maths, difficulty: .intermediate, question: "When is matrix multiplication possible?",
            keywords: ["matrix", "columns", "rows", "equal"],
            idealAnswer: "Matrix multiplication is possible when the first matrix's column count equals the second matrix's row count.",
            tip: "Columns of the first equal rows of the second."),
        // ML (21-26)
        InterviewQuestion(id: 21, topic: .ml, difficulty: .basic, question: "What is machine learning, in simple words?",
            keywords: ["machine learning", "learn", "patterns", "data", "predictions"],
            idealAnswer: "Machine learning lets computers learn patterns from data and make predictions on new data.",
            tip: "Patterns from data, predictions on new data."),
        InterviewQuestion(id: 22, topic: .ml, difficulty: .basic, question: "What is training data?",
            keywords: ["training data", "example", "model", "learns"],
            idealAnswer: "Training data is the example data a model learns from.",
            tip: "One sentence is enough."),
        InterviewQuestion(id: 23, topic: .ml, difficulty: .intermediate, question: "What is overfitting, and how do you reduce it?",
            keywords: ["overfitting", "memorising", "training", "new data", "regularization", "cross-validation"],
            idealAnswer: "Overfitting is memorising training data and failing on new data. I reduce it with more data, regularization, simpler models, and cross-validation.",
            tip: "Give the definition plus at least two fixes."),
        InterviewQuestion(id: 24, topic: .ml, difficulty: .intermediate, question: "What is the difference between regression and classification?",
            keywords: ["regression", "classification", "continuous", "number", "category", "class"],
            idealAnswer: "Regression predicts a continuous number. Classification predicts a category or class.",
            tip: "Number versus category."),
        InterviewQuestion(id: 25, topic: .ml, difficulty: .intermediate, question: "Is accuracy enough? When should you look at precision and recall?",
            keywords: ["accuracy", "imbalanced", "precision", "recall", "false positives", "false negatives"],
            idealAnswer: "Accuracy can mislead on imbalanced data. Precision and recall show the cost of false positives and false negatives.",
            tip: "Say when accuracy misleads: imbalanced data."),
        InterviewQuestion(id: 26, topic: .ml, difficulty: .intermediate, question: "What is regularization?",
            keywords: ["regularization", "penalty", "weights", "simpler", "overfitting"],
            idealAnswer: "Regularization adds a penalty on large weights to keep the model simpler and reduce overfitting.",
            tip: "Penalty on large weights."),
        // DL (27-32)
        InterviewQuestion(id: 27, topic: .dl, difficulty: .basic, question: "What is a neural network, in simple words?",
            keywords: ["neural network", "layers", "neurons", "weights", "learn"],
            idealAnswer: "A neural network is layers of connected neurons with weights that adjust during learning.",
            tip: "Layers, neurons, weights."),
        InterviewQuestion(id: 28, topic: .dl, difficulty: .basic, question: "Why do we need an activation function?",
            keywords: ["activation", "non-linearity", "complex", "patterns"],
            idealAnswer: "Activation functions add non-linearity so the network can learn complex patterns.",
            tip: "Non-linearity is the answer."),
        InterviewQuestion(id: 29, topic: .dl, difficulty: .intermediate, question: "What is backpropagation?",
            keywords: ["backpropagation", "gradient", "loss", "chain rule", "weights", "update"],
            idealAnswer: "Backpropagation computes the gradient of the loss for each weight using the chain rule, so the weights can be updated.",
            tip: "Chain rule plus weight update."),
        InterviewQuestion(id: 30, topic: .dl, difficulty: .intermediate, question: "Why are CNNs best for images?",
            keywords: ["cnn", "convolution", "local", "features", "edges", "spatial"],
            idealAnswer: "CNNs use convolution filters that detect local features like edges while respecting the spatial structure of images.",
            tip: "Local features and spatial structure."),
        InterviewQuestion(id: 31, topic: .dl, difficulty: .intermediate, question: "In a Transformer, what is attention?",
            keywords: ["attention", "token", "weigh", "relevant"],
            idealAnswer: "Attention lets each token weigh which other tokens are most relevant to it when building its representation.",
            tip: "Weigh which other tokens matter most."),
        InterviewQuestion(id: 32, topic: .dl, difficulty: .intermediate, question: "What does an optimizer do? What is the difference between Adam and SGD?",
            keywords: ["optimizer", "update", "weights", "gradients", "adam", "sgd", "learning rate"],
            idealAnswer: "An optimizer updates weights using gradients. Adam adapts the learning rate per parameter, while plain SGD uses one rate for all.",
            tip: "Per-parameter rate versus one rate."),
        // GenAI (33-38)
        InterviewQuestion(id: 33, topic: .genai, difficulty: .basic, question: "What is tokenization, and why is it important for LLMs?",
            keywords: ["tokenization", "tokens", "vocabulary", "id", "embed"],
            idealAnswer: "Tokenization splits text into tokens from a fixed vocabulary. Each token maps to an ID the model embeds and processes.",
            tip: "Text to tokens to IDs."),
        InterviewQuestion(id: 34, topic: .genai, difficulty: .basic, question: "What is an LLM?",
            keywords: ["llm", "large language model", "trained", "text", "predict", "generate"],
            idealAnswer: "An LLM is a large language model trained on huge amounts of text to predict and generate text.",
            tip: "Trained on huge text, predicts text."),
        InterviewQuestion(id: 35, topic: .genai, difficulty: .intermediate, question: "What are embeddings?",
            keywords: ["embeddings", "vectors", "meaning", "similar", "close"],
            idealAnswer: "Embeddings are dense vectors that capture meaning, so similar ideas sit close together in vector space.",
            tip: "Similar ideas sit close together."),
        InterviewQuestion(id: 36, topic: .genai, difficulty: .intermediate, question: "What is RAG, and when do you use it?",
            keywords: ["rag", "retrieve", "documents", "context", "ground", "evidence"],
            idealAnswer: "RAG retrieves relevant documents, adds them as context, and grounds the LLM answer in that evidence.",
            tip: "Retrieve, add as context, ground the answer."),
        InterviewQuestion(id: 37, topic: .genai, difficulty: .intermediate, question: "How do you write a good prompt in prompt engineering?",
            keywords: ["prompt", "clear", "specific", "context", "format", "examples"],
            idealAnswer: "A good prompt is clear and specific, gives context, states the output format, and includes examples when needed.",
            tip: "Clear, context, format, examples."),
        InterviewQuestion(id: 38, topic: .genai, difficulty: .intermediate, question: "Why do we use a vector database?",
            keywords: ["vector database", "embeddings", "similarity", "nearest", "search"],
            idealAnswer: "A vector database stores embeddings and performs fast similarity, nearest-neighbour search over them.",
            tip: "Stores embeddings, fast similarity search."),
        // Agents (39-43)
        InterviewQuestion(id: 39, topic: .agents, difficulty: .basic, question: "What is an AI agent, and how is it different from a chatbot?",
            keywords: ["agent", "tools", "multi-step", "actions", "goal", "chatbot"],
            idealAnswer: "An agent uses an LLM plus tools to take multi-step actions toward a goal, not just reply with text like a basic chatbot.",
            tip: "Tools plus multi-step actions is the difference."),
        InterviewQuestion(id: 40, topic: .agents, difficulty: .basic, question: "What is tool calling?",
            keywords: ["tool calling", "function", "api", "arguments", "structured"],
            idealAnswer: "Tool calling lets the model choose an external function or API and supply its arguments in a structured format.",
            tip: "Model chooses the tool and its arguments."),
        InterviewQuestion(id: 41, topic: .agents, difficulty: .intermediate, question: "Why is agent memory important?",
            keywords: ["memory", "remember", "previous", "steps", "state", "coherent"],
            idealAnswer: "Memory lets an agent remember previous steps and state so multi-step tasks stay coherent.",
            tip: "Remember previous steps."),
        InterviewQuestion(id: 42, topic: .agents, difficulty: .intermediate, question: "What are guardrails in agents?",
            keywords: ["guardrails", "constrain", "allowed tools", "approval", "risky"],
            idealAnswer: "Guardrails constrain agent actions — allowed tools, checked inputs and outputs, and human approval for risky steps.",
            tip: "Allowed tools plus human approval."),
        InterviewQuestion(id: 43, topic: .agents, difficulty: .intermediate, question: "How do you evaluate an agent?",
            keywords: ["evaluate", "task completion", "tool calls", "cost", "latency", "human review"],
            idealAnswer: "I evaluate agents by task completion rate, correctness of tool calls, cost and latency, and human review of outcomes.",
            tip: "Give at least three measures."),
        // MLOps (44-49)
        InterviewQuestion(id: 44, topic: .mlops, difficulty: .basic, question: "What is deployment?",
            keywords: ["deployment", "server", "users", "access"],
            idealAnswer: "Deployment means putting the application on a server so real users can access it.",
            tip: "Server so real users can access it."),
        InterviewQuestion(id: 45, topic: .mlops, difficulty: .basic, question: "What is an API, in simple words?",
            keywords: ["api", "interface", "programs", "request", "respond"],
            idealAnswer: "An API is an interface through which two programs request and respond to each other.",
            tip: "Two programs talking to each other."),
        InterviewQuestion(id: 46, topic: .mlops, difficulty: .intermediate, question: "Why is FastAPI popular for ML services?",
            keywords: ["fastapi", "fast", "async", "pydantic", "validate", "docs"],
            idealAnswer: "FastAPI is popular for ML services because it is fast, async, validates data with Pydantic, and auto-generates API docs.",
            tip: "Fast, async, Pydantic, auto docs."),
        InterviewQuestion(id: 47, topic: .mlops, difficulty: .intermediate, question: "What is Docker? Why do we use containers?",
            keywords: ["docker", "container", "packages", "environment", "same everywhere"],
            idealAnswer: "Docker packages an app with its environment into a container that runs the same everywhere.",
            tip: "Same everywhere is the payoff."),
        InterviewQuestion(id: 48, topic: .mlops, difficulty: .intermediate, question: "Why do we need model monitoring after deployment?",
            keywords: ["monitoring", "drift", "performance", "drops", "retrain"],
            idealAnswer: "Monitoring detects data drift and performance drops after deployment so the model can be retrained or fixed.",
            tip: "Drift and performance drops."),
        InterviewQuestion(id: 49, topic: .mlops, difficulty: .intermediate, question: "What is CI/CD?",
            keywords: ["ci/cd", "automatically", "tests", "deploys", "pipeline", "push"],
            idealAnswer: "CI/CD automatically tests and deploys code changes through a pipeline whenever code is pushed.",
            tip: "Automatically test and deploy on push."),
        // Coding (50-54)
        InterviewQuestion(id: 50, topic: .coding, difficulty: .basic, question: "What is the output if you sum numbers equals 10, 20, 30 in a list?",
            keywords: ["sum", "60", "list"],
            idealAnswer: "The sum of 10, 20 and 30 is 60.",
            tip: "Say the answer, then the method: sum of the list."),
        InterviewQuestion(id: 51, topic: .coding, difficulty: .basic, question: "What is a loop?",
            keywords: ["loop", "repeats", "for", "while", "condition"],
            idealAnswer: "A loop repeats a block of code — for repeats over items, while repeats while a condition is true.",
            tip: "For versus while."),
        InterviewQuestion(id: 52, topic: .coding, difficulty: .intermediate, question: "How do you check if a string is a palindrome?",
            keywords: ["palindrome", "reverse", "two pointers", "compare"],
            idealAnswer: "I compare the string with its reverse, s equals s reversed, or use two pointers from both ends.",
            tip: "Reverse compare is the simplest answer."),
        InterviewQuestion(id: 53, topic: .coding, difficulty: .intermediate, question: "How do you count word frequency in a dictionary?",
            keywords: ["dictionary", "word", "frequency", "count", "increment"],
            idealAnswer: "I iterate over the words and use a dictionary to store and increment each word's count.",
            tip: "Iterate, then increment the count."),
        InterviewQuestion(id: 54, topic: .coding, difficulty: .intermediate, question: "How do you start debugging code that has a bug?",
            keywords: ["debugging", "reproduce", "error", "isolate", "prints", "tests"],
            idealAnswer: "First I reproduce the bug, read the error, then isolate it with prints or tests step by step until I find the failing line.",
            tip: "Reproduce, read, isolate — in that order."),
        // HR (55-59)
        // v1.7: Q55 is now a REAL self-introduction he can read on
        // screen and practise — only true facts (his name, IIT Patna
        // AIML pursuing, what he is learning, the role he wants).
        // No invented projects or experience.
        InterviewQuestion(id: 55, topic: .hr, difficulty: .basic, question: "Tell me about yourself.",
            keywords: ["name", "pursuing", "iit patna", "python", "machine learning", "ai engineer", "role"],
            idealAnswer: "My name is Shaik Mahmmad Siraz. I am pursuing Artificial Intelligence and Machine Learning at IIT Patna. I am learning Python, machine learning, and large language models, and I am looking for an entry-level AI Engineer role where I can keep learning and contribute.",
            tip: "Keep it to about one minute: name, what you are pursuing, what you are learning, and the role you want."),
        InterviewQuestion(id: 56, topic: .hr, difficulty: .basic, question: "What is your strength? Answer with an example.",
            keywords: ["strength", "example", "result"],
            idealAnswer: "I name one real strength and prove it with a short example of what I did and its result.",
            tip: "One strength, one example, one result."),
        InterviewQuestion(id: 57, topic: .hr, difficulty: .intermediate, question: "How do you explain a project to an interviewer?",
            keywords: ["project", "problem", "solution", "role", "tools", "result"],
            idealAnswer: "I explain the problem, my solution, my specific role, the tools I used, and the measurable result.",
            tip: "Problem, solution, your role, result."),
        InterviewQuestion(id: 58, topic: .hr, difficulty: .intermediate, question: "What do you say when they ask about your weakness?",
            keywords: ["weakness", "honest", "improve", "steps", "progress"],
            idealAnswer: "I am honest about a real weakness and describe the concrete steps I am taking to improve it, with progress.",
            tip: "Honest weakness plus concrete improvement steps."),
        InterviewQuestion(id: 59, topic: .hr, difficulty: .intermediate, question: "How do you handle a disagreement in a team?",
            keywords: ["disagreement", "listen", "trade-offs", "respectfully", "shared goal"],
            idealAnswer: "I listen first, discuss the trade-offs respectfully, and decide based on the team's shared goal.",
            tip: "Listen first, then decide on the shared goal."),
        // HR (60-63) — v1.7 Interview Prep: the other classic
        // questions every interviewer asks a fresher. Sample answers
        // are short templates in his own true situation — no invented
        // jobs, projects or experience.
        InterviewQuestion(id: 60, topic: .hr, difficulty: .intermediate, question: "Why should we hire you?",
            keywords: ["quick learner", "python", "machine learning", "work hard", "contribute", "fresher"],
            idealAnswer: "You should hire me because I am a quick learner with a base in Python and machine learning. As a fresher, I will work hard to learn your stack and contribute.",
            tip: "Give a reason, not just 'I am hardworking' — quick learner + base skills + what you will do."),
        InterviewQuestion(id: 61, topic: .hr, difficulty: .intermediate, question: "Why do you want this AI Engineer role?",
            keywords: ["ai engineer", "learn", "python", "machine learning", "llm", "build"],
            idealAnswer: "I want this AI Engineer role because I love building with Python, machine learning, and LLMs, and I want to learn by solving real problems and building products people actually use.",
            tip: "Say what attracts you to the work itself, not just the salary."),
        InterviewQuestion(id: 62, topic: .hr, difficulty: .intermediate, question: "Where do you see yourself in five years?",
            keywords: ["five years", "ai engineer", "skills", "projects", "team", "grow"],
            idealAnswer: "In five years I see myself as a strong AI Engineer, with deep skills in machine learning and LLMs, shipping real projects and helping my team grow.",
            tip: "Show growth in the same field — skills, real projects, team."),
        InterviewQuestion(id: 63, topic: .hr, difficulty: .intermediate, question: "Tell me about a challenge you faced and how you handled it.",
            keywords: ["challenge", "problem", "small steps", "learned", "patient"],
            idealAnswer: "When I faced a challenge in my learning, I broke the problem into small steps, practised each step, asked for help when I was stuck, and kept going until it worked. I learned to stay patient and break big problems down.",
            tip: "Use challenge, what you did, and what you learned — keep it short."),
    ]
    static func questions(for topic: Topic) -> [InterviewQuestion] {
        topic == .all ? all : all.filter { $0.topic == topic }
    }
}

// MARK: - v1.8 session total marks
/// Total marks for one finished session (Mock 5 Qs, Interview Prep,
/// or any Practice run ended with End session): the average of the
/// per-question marks, so a relevant answer counts high and an
/// irrelevant one pulls the total down. One entry per question —
/// a retry replaces the first attempt for that question.
struct SessionSummary {
    let evaluations: [Evaluation]
    var count: Int { evaluations.count }
    var totalPoints: Int { evaluations.map(\.overallScore).reduce(0, +) }
    var maxPoints: Int { count * 100 }
    var averageScore: Int {
        guard count > 0 else { return 0 }
        return totalPoints / count
    }
    var relevantCount: Int { evaluations.filter(\.isRelevant).count }
    var partlyCount: Int { evaluations.filter { $0.relevanceLabel == "Partly relevant" }.count }
    var irrelevantCount: Int { evaluations.filter(\.isIrrelevant).count }
    var grade: String {
        switch averageScore {
        case 80...100: return "Interview ready — pass"
        case 60..<80: return "Good — almost there"
        case 40..<60: return "Needs work"
        default: return "Needs practice"
        }
    }
    var spokenSummary: String {
        "Session complete. You scored \(averageScore) out of 100 across \(count) question\(count == 1 ? "" : "s"). \(relevantCount) relevant, \(partlyCount) partly relevant, \(irrelevantCount) off-topic. \(grade)."
    }
}
