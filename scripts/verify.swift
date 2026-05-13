import Foundation

@main
struct VerifyDict {
    static func main() async {
        let dbPath = "test_verify.db"
        print("Building sample database...")
        do {
            try WubiDictBuilder.buildSample(to: dbPath)
            
            let dict = await WubiDict(dbPath: dbPath)
            print("Opening dictionary...")
            try await dict.open()
            
            print("Testing input 'g'...")
            await dict.append("g")
            
            let buffer = await dict.buffer
            let candidates = await dict.candidates
            
            print("Buffer: \(buffer)")
            print("Candidates: \(candidates.map { $0.text })")
            
            if candidates.first?.text == "一" {
                print("✅ SUCCESS: 'g' mapped to '一'")
            } else {
                print("❌ FAILURE: 'g' mapped to \(String(describing: candidates.first?.text))")
            }
            
            await dict.close()
            try? FileManager.default.removeItem(atPath: dbPath)
            print("Verification finished.")
        } catch {
            print("Error: \(error)")
        }
    }
}
