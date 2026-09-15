import SwiftUI
import Combine

// ============================================================================
//  LocalState — @State 的替代品
//
//  为什么不用 SwiftUI 原生的 @State？
//  @State 在 Swift 5.9 之后改由 macro 实作（SwiftUIMacros），而那份 macro
//  外挂只随 Xcode.app 一起安装。本机只装了 Command Line Tools（没有 10GB 的
//  Xcode），所以 `@State` 会报 "plugin for module 'SwiftUIMacros' not found"。
//
//  这个包装器用老式的 @StateObject ＋ @Published 实作同样的语义：
//  View 内部持有的局部状态、变更会触发重绘、$ 取得到 Binding。
//  其他 @StateObject / @ObservedObject / @Binding / @Environment 都不是 macro，
//  一律照用原生版本。
// ============================================================================

@propertyWrapper
struct LocalState<Value>: DynamicProperty {
    private final class Storage: ObservableObject {
        @Published var value: Value
        init(_ value: Value) { self.value = value }
    }

    @StateObject private var storage: Storage

    init(wrappedValue: Value) {
        _storage = StateObject(wrappedValue: Storage(wrappedValue))
    }

    var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.value = newValue }
    }

    var projectedValue: Binding<Value> {
        Binding(
            get: { storage.value },
            set: { storage.value = $0 }
        )
    }
}
