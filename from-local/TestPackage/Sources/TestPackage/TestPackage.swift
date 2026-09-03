@main
public struct TestPackage {
    public private(set) var text = "Hello, World!"

    public static func main() {
        print(TestPackage().text)
    }
}
