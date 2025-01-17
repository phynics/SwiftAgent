import Foundation
import SwiftAgent

/// A tool for fetching data from a URL.
///
/// `URLFetchTool` performs HTTP GET requests to retrieve data from web resources.
///
/// ## Features
/// - Perform HTTP GET requests.
/// - Handle and validate URLs.
/// - Return fetched data as a string.
///
/// ## Limitations
/// - Only supports HTTP and HTTPS URLs.
/// - Cannot handle complex request configurations like custom headers or POST requests.
public struct URLFetchTool: Tool {
    public typealias Input = FetchInput
    public typealias Output = FetchOutput
    
    public let name = "url_fetch"
    
    public let description = """
    A tool for fetching data from a URL. Use this tool to retrieve content from web pages or APIs.
    Limitations:
    - Only supports HTTP and HTTPS URLs.
    - Returns data as plain text.
    - Cannot handle POST requests or custom headers.
    """
    
    public let guide: String? = """
    # url_fetch Guide
    
    ## Description
    `url_fetch` retrieves data from a specified URL via HTTP GET requests.
    
    ### Key Features
    - Simple interface for fetching web resources.
    - Ensures the URL is valid before making a request.
    
    ### Limitations
    - Only supports HTTP and HTTPS URLs.
    - Limited to plain text responses.
    
    ## Parameters
    - **url**:
      - **Type**: `String`
      - **Description**: The URL to fetch data from.
      - **Requirements**: Must be a valid HTTP or HTTPS URL.
    
    ## Examples
    
    ### Example 1: Fetching a JSON API
    ```json
    {
      "url": "https://api.example.com/data"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": true,
      "output": "{\"key\": \"value\"}",
      "metadata": {
        "status": "200",
        "url": "https://api.example.com/data"
      }
    }
    ```
    
    ### Example 2: Invalid URL
    ```json
    {
      "url": "ftp://example.com"
    }
    ```
    **Expected Output**:
    ```json
    {
      "success": false,
      "output": "Invalid URL",
      "metadata": {
        "error": "URL must use HTTP or HTTPS"
      }
    }
    ```
    """
    
    public let parameters: JSONSchema = .object(
        description: "Schema for URL fetching",
        properties: [
            "url": .string(description: "The URL to fetch data from")
        ],
        required: ["url"]
    )
    
    public init() {}
    
    public func run(_ input: FetchInput) async throws -> FetchOutput {
        guard let url = URL(string: input.url), url.scheme == "http" || url.scheme == "https" else {
            return FetchOutput(
                success: false,
                output: "Invalid URL",
                metadata: ["error": "URL must use HTTP or HTTPS"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return FetchOutput(
                    success: false,
                    output: "Invalid response",
                    metadata: ["error": "Response is not HTTP"]
                )
            }

            let output = String(data: data, encoding: .utf8) ?? ""
            return FetchOutput(
                success: httpResponse.statusCode == 200,
                output: output,
                metadata: [
                    "status": "\(httpResponse.statusCode)",
                    "url": input.url
                ]
            )
        } catch {
            return FetchOutput(
                success: false,
                output: "Failed to fetch data: \(error.localizedDescription)",
                metadata: ["error": error.localizedDescription]
            )
        }
    }
}

// MARK: - Input/Output Types

/// The input structure for fetching data.
public struct FetchInput: Codable, Sendable {
    /// The URL to fetch data from.
    public let url: String
    
    public init(url: String) {
        self.url = url
    }
}

/// The output structure for fetched data.
public struct FetchOutput: Codable, Sendable, CustomStringConvertible {
    /// Whether the fetch operation succeeded.
    public let success: Bool
    
    /// The fetched data as a string.
    public let output: String
    
    /// Additional metadata about the fetch operation.
    public let metadata: [String: String]
    
    public init(success: Bool, output: String, metadata: [String: String]) {
        self.success = success
        self.output = output
        self.metadata = metadata
    }
    
    public var description: String {
        let status = success ? "Success" : "Failed"
        let metadataString = metadata.isEmpty ? "" : "\nMetadata:\n" + metadata.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
        
        return """
        Fetch [\(status)]
        Output: \(output)\(metadataString)
        """
    }
}
