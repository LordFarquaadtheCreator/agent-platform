import Foundation

/// Categories for pop-culture name generation
public enum NameCategory: String, Codable, CaseIterable, Sendable {
    case sciFi = "sci-fi"
    case fantasy = "fantasy"
    case comics = "comics"
    case games = "games"
    case bollywood = "bollywood"

    public var displayName: String {
        switch self {
        case .sciFi: return "Sci-Fi"
        case .fantasy: return "Fantasy"
        case .comics: return "Comics"
        case .games: return "Games"
        case .bollywood: return "Bollywood"
        }
    }
}

/// Generates unique, cute pop-culture inspired names for agents
public final class AgentNamingService: Sendable {
    private let repository: AgentRepository
    private let logger = AppLogger.agentNaming
    
    /// Curated pop-culture name catalogues by category (2000s+ focus)
    private static let nameCatalogues: [NameCategory: [String]] = [
        .sciFi: [
            "Cobb", "Ariadne", "Arthur", "Eames", "Saito", "Fischer", "Mal", "Yusuf",
            "Cooper", "Murph", "Brand", "Mann", "TARS", "CASE", "Miller", "Edmunds",
            "Watney", "Johansen", "Lewis", "Beck", "Vogel", "Martinez",
            "Ryan", "Jack", "Atlas", "Frank", "Ishigami", "Dunn",
            "Theo", "Kee", "Joi", "K", "Wallace", "Mariette", "Luv",
            "Louise", "Ian", "Donnelly", "Costello", "Weber", "Halpern",
            "Wade", "Art3mis", "Aech", "Shoto", "Daito", "Sorrento", "I-r0k",
            "Amelia", "Joseph", "Sully", "Neytiri", "Quaritch", "Grace", "Norm"
        ],
        .fantasy: [
            "Aloy", "Rost", "Sylens", "Erend", "Talanah", "Varl", "Helis", "HADES",
            "Kratos", "Atreus", "Freya", "Baldur", "Mimir", "Brok", "Sindri", "Thor", "Odin",
            "Geralt", "Ciri", "Yennefer", "Triss", "Dandelion", "Vesemir", "Eskel", "Lambert",
            "Targaryen", "Stark", "Lannister", "Snow", "Arya", "Sansa", "Daenerys", "Tyrion",
            "Aragorn", "Legolas", "Gimli", "Gandalf", "Frodo", "Samwise", "Gollum", "Thranduil",
            "Kaladin", "Shallan", "Dalinar", "Adolin", "Jasnah", "Szeth", "Lift", "Wit",
            "Vin", "Kelsier", "Elend", "Sazed", "Kaladin", "Shallan", "Dalinar"
        ],
        .comics: [
            "Stark", "Rogers", "Thor", "Banner", "Natasha", "Clint", "Peter", "TChalla",
            "Strange", "Wanda", "Vision", "Sam", "Bucky", "Scott", "Hope", "Carol",
            "Shuri", "Okoye", "Nakia", "Killmonger", "Valkyrie", "Korg", "Miek",
            "Quill", "Gamora", "Drax", "Rocket", "Groot", "Nebula", "Mantis", "Yondu",
            "Parker", "Morales", "Gwen", "Hammerhead", "Osborn", "Octavius", "Toomes",
            "Wayne", "Kent", "Prince", "Allen", "Curry", "Stone", "Lane", "Gordon"
        ],
        .games: [
            "Joel", "Ellie", "Abby", "Tess", "Tommy", "Bill", "Dina", "Jesse", "Lev",
            "Arthur", "John", "Dutch", "Sadie", "Charles", "Javier", "Micah", "Hosea",
            "V", "Johnny", "Judy", "Panam", "River", "Kerry", "Rogue", "Dex",
            "Tarnished", "Melina", "Ranni", "Fia", "Nepheli", "Blaidd", "Alexander", "Patches",
            "Tav", "Astarion", "Shadowheart", "Gale", "Karlach", "Wyll", "Laezel", "The Dark Urge",
            "Zagreus", "Melinoe", "Thanatos", "Megaera", "Achilles", "Nyx", "Chaos", "Hades",
            "Madeline", "Badeline", "Theo", "Granny", "Oshiro", "Bird",
            "Hornet", "Knight", "Quirrel", "Cloth", "Zote", "Tiso", "Bretta",
            "Steve", "Alex", "Villager", "Creeper", "Enderman", "Zombie", "Skeleton",
            "Jonesy", "Peely", "Fishstick", "Midas", "Jules", "Drift", "Raven",
            "Jett", "Sage", "Phoenix", "Reyna", "Omen", "Cypher", "Sova", "Viper", "Brimstone",
            "Tracer", "Widow", "Reaper", "Mercy", "Genji", "Hanzo", "Dva", "Soldier", "Ana",
            "Jinx", "Vi", "Caitlyn", "Jayce", "Ekko", "Viktor", "Silco", "Mel",
            "Niko", "Chelsea", "Kep", "Alula", "Calamus", "Rue", "Prophetbot",
            "Hollow", "Shovel", "Plague", "Specter", "King", "Treasure"
        ],
        .bollywood: [
            "Amitabh", "Shahrukh", "Salman", "Aamir", "Akshay", "Ajay", "Hrithik", "Ranbir", "Ranveer",
            "Shahid", "Varun", "Tiger", "Vicky", "Kartik", "Sidharth", "Aditya", "Rajkumar", "Ayushmann",
            "Irrfan", "Nawaz", "Manoj", "Pankaj", "Anupam", "Naseer", "Om", "Amrish", "Danny",
            "Deepika", "Priyanka", "Katrina", "Kareena", "Kangana", "Alia", "Shraddha", "Anushka", "Sonam",
            "Vidya", "Tabu", "Rani", "Madhuri", "Sridevi", "Rekha", "Hema", "Jaya", "Shabana",
            "Kiara", "Kriti", "Sara", "Janhvi", "Tara", "Ananya", "Bhumi", "Taapsee", "Radhika",
            "Rishi", "Sanjay", "Sunny", "Bobby", "Jackie", "Anil", "Juhi", "Madhuri",
            "Dharmendra", "Vinod", "Shatrughan", "Mithun", "Govinda", "Chunky", "Shakti", "Pran"
        ],
    ]

    public struct GeneratedName: Sendable {
        public let displayName: String
        public let category: NameCategory
        public let baseName: String
        public let seed: Int
        
        public init(displayName: String, category: NameCategory, baseName: String, seed: Int) {
            self.displayName = displayName
            self.category = category
            self.baseName = baseName
            self.seed = seed
        }
    }
    
    public init(repository: AgentRepository) {
        self.repository = repository
    }
    
    /// Generate a unique pop-culture inspired name
    public func generateUniqueName() async throws -> GeneratedName {
        let maxAttempts = 100
        
        for attempt in 0..<maxAttempts {
            let category = randomCategory()
            let baseName = randomName(from: category)
            let seed = Int.random(in: 1...99)
            let displayName = "\(baseName)-\(String(format: "%02d", seed))"
            
            // Check uniqueness
            let exists = try await repository.existsWithName(name: displayName)
            if !exists {
                logger.info("Generated unique agent name: \(displayName) from \(category.displayName)")
                return GeneratedName(
                    displayName: displayName,
                    category: category,
                    baseName: baseName,
                    seed: seed
                )
            }
        }
        
        // Fallback: use UUID suffix if all attempts fail
        let fallback = "Agent-\(UUID().uuidString.prefix(8).uppercased())"
        logger.warning("Could not generate unique pop-culture name, using fallback: \(fallback)")
        return GeneratedName(
            displayName: fallback,
            category: .sciFi,
            baseName: "Agent",
            seed: 0
        )
    }
    
    /// Regenerate a name for an existing agent while preserving audit trail
    public func regenerateName(for agentId: String) async throws -> GeneratedName {
        let newName = try await generateUniqueName()
        logger.info("Regenerated name for agent \(agentId): \(newName.displayName)")
        return newName
    }
    
    /// Get all available name categories
    public func availableCategories() -> [NameCategory] {
        NameCategory.allCases
    }
    
    /// Get names from a specific category
    public func names(from category: NameCategory) -> [String] {
        AgentNamingService.nameCatalogues[category] ?? []
    }
    
    /// Get total name pool size
    public func totalNamePoolSize() -> Int {
        AgentNamingService.nameCatalogues.values.reduce(0) { $0 + $1.count }
    }
    
    /// Create display info for the agent name
    public func nameInfo(for name: GeneratedName) -> String {
        return "\(name.displayName) (\(name.category.displayName): \(name.baseName))"
    }
    
    // MARK: - Private Methods
    
    private func randomCategory() -> NameCategory {
        NameCategory.allCases.randomElement()!
    }
    
    private func randomName(from category: NameCategory) -> String {
        guard let names = AgentNamingService.nameCatalogues[category],
              !names.isEmpty else {
            return "Unknown"
        }
        return names.randomElement()!
    }
}

// MARK: - Name Compatibility Extension

extension AgentNamingService {
    /// Generate a deterministic name based on a seed (for reproducibility)
    public func generateDeterministicName(seed: Int, category: NameCategory? = nil) -> GeneratedName {
        var rng = SeededRandom(seed: seed)
        
        let selectedCategory = category ?? {
            let allCategories = Array(NameCategory.allCases)
            return allCategories[rng.nextInt(in: 0..<allCategories.count)]
        }()
        
        let names = AgentNamingService.nameCatalogues[selectedCategory] ?? []
        guard !names.isEmpty else {
            return GeneratedName(displayName: "Agent \(seed)", category: selectedCategory, baseName: "Agent", seed: seed)
        }
        
        let index = rng.nextInt(in: 0..<names.count)
        let baseName = names[index]
        let nameSeed = rng.nextInt(in: 1...99)
        let displayName = "\(baseName)-\(String(format: "%02d", nameSeed))"
        
        return GeneratedName(
            displayName: displayName,
            category: selectedCategory,
            baseName: baseName,
            seed: nameSeed
        )
    }
}

// MARK: - Seeded Random Generator

/// Deterministic random number generator for reproducible name generation
public struct SeededRandom {
    private var generator: SeededRandomNumberGenerator
    
    public init(seed: Int) {
        self.generator = SeededRandomNumberGenerator(seed: seed)
    }
    
    public mutating func nextInt(in range: Range<Int>) -> Int {
        let value = generator.next()
        let rangeSize = UInt64(range.upperBound - range.lowerBound)
        let boundedValue = Int(value % rangeSize) + range.lowerBound
        return boundedValue
    }
    
    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let value = generator.next()
        let rangeSize = UInt64(range.upperBound - range.lowerBound + 1)
        let boundedValue = Int(value % rangeSize) + range.lowerBound
        return boundedValue
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
    }
    
    mutating func next() -> UInt64 {
        // xorshift64* algorithm
        state ^= state << 12
        state ^= state >> 25
        state ^= state << 27
        return state &* 2685821657736338717
    }
}

