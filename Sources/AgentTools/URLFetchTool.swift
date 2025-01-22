import Foundation
import SwiftAgent

/// A tool for fetching data from a URL.
///
/// `URLFetchTool` performs HTTP GET requests to retrieve data from web resources.
///
/// ## Usage Guidance
/// - Use this tool **only** if the user's request requires retrieving **external** data from a web resource.
/// - For trivial tasks (e.g., greetings) or reasoning-based answers that do not require external data,
///   do **not** invoke this tool.
/// - Ensure the URL is valid (HTTP/HTTPS) before calling this tool.
///
/// ## Features
/// - Perform HTTP GET requests in a non-interactive context.
/// - Validate URLs and return the response as plain text.
///
/// ## Limitations
/// - Only supports HTTP and HTTPS URLs.
/// - Cannot handle POST requests, custom headers, or complex configurations.
/// - Does not parse or structure the fetched data; it returns raw text.
///
/// ## Example Usage (Reference Only)
/// This example is provided for demonstration. It does not imply the tool must always be used.
/// ```json
/// {
///   "url": "https://api.example.com/data"
/// }
/// ```
/// **Expected Output**:
/// ```json
/// {
///   "success": true,
///   "output": "{\"key\": \"value\"}",
///   "metadata": {
///     "status": "200",
///     "url": "https://api.example.com/data"
///   }
/// }
/// ```
///
/// Always confirm that the user genuinely needs external data from the provided URL before using `URLFetchTool`.
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
    
    /// A more detailed guide for the `url_fetch` tool.
    ///
    /// Emphasizes that examples are for reference only and clarifies the limitations.
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
    
    /// Defines the JSON schema for inputs to this tool.
    ///
    /// - url: The URL (HTTP or HTTPS) from which to fetch data.
    public let parameters: JSONSchema = .object(
        description: "Schema for URL fetching",
        properties: [
            "url": .string(description: "The URL to fetch data from")
        ],
        required: ["url"]
    )
    
    public init() {}
    
    /// Executes the fetch operation asynchronously.
    ///
    /// - Parameter input: A `FetchInput` containing a valid HTTP/HTTPS URL.
    /// - Returns: A `FetchOutput` containing success status, raw output text, and metadata.
    ///
    /// This function will return `success: false` if the URL is invalid or if the request fails.
    public func run(_ input: FetchInput) async throws -> FetchOutput {
        // Validate the URL scheme
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
            
            // Ensure we have a valid HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                return FetchOutput(
                    success: false,
                    output: "Invalid response",
                    metadata: ["error": "Response is not HTTP"]
                )
            }
            
            // Convert data to String (UTF-8). If conversion fails, we fallback to empty.
            let outputText = String(data: data, encoding: .utf8) ?? ""
            
            // Successful if status code is 200
            let isSuccess = (httpResponse.statusCode == 200)
            
            return FetchOutput(
                success: isSuccess,
                output: outputText,
                metadata: [
                    "status": "\(httpResponse.statusCode)",
                    "url": input.url
                ]
            )
        } catch {
            // Handle general errors (e.g., network unreachable, timeouts)
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
    /// The URL to fetch data from (must be HTTP or HTTPS).
    public let url: String
    
    public init(url: String) {
        self.url = url
    }
}

/// The output structure for fetched data.
public struct FetchOutput: Codable, Sendable, CustomStringConvertible {
    /// Whether the fetch operation succeeded (status 200).
    public let success: Bool
    
    /// The fetched data as a string (raw text).
    public let output: String
    
    /// Additional metadata about the fetch operation (status code, url, etc.).
    public let metadata: [String: String]
    
    public init(success: Bool, output: String, metadata: [String: String]) {
        self.success = success
        self.output = output
        self.metadata = metadata
    }
    
    /// A human-readable description of the fetch result.
    public var description: String {
        let statusText = success ? "Success" : "Failed"
        let metadataInfo = metadata.isEmpty
        ? ""
        : "\nMetadata:\n" + metadata.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
        
        return """
        Fetch [\(statusText)]
        Output: \(output)\(metadataInfo)
        """
    }
}
