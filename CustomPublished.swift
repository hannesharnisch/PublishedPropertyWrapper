import Foundation
import Combine

/// A type that publishes a property marked with an attribute.
///
/// Publishing a property with the `@CustomPublished` attribute creates a publisher of this type. You access the publisher with the `$` operator, as shown here:
///
///     class Weather {
///         @CustomPublished var temperature: Double
///         init(temperature: Double) {
///             self.temperature = temperature
///         }
///     }
///
///     let weather = Weather(temperature: 20)
///     cancellable = weather.$temperature
///         .sink() {
///             print ("Temperature now: \($0)")
///     }
///     weather.temperature = 25
///
///     // Prints:
///     // Temperature now: 20.0
///     // Temperature now: 25.0
///
/// When the property changes, publishing occurs in the property's `willSet` block, meaning subscribers receive the new value before it's actually set on the property. In the above example, the second time the sink executes its closure, it receives the parameter value `25`. However, if the closure evaluated `weather.temperature`, the value returned would be `20`.
///
@propertyWrapper
class CustomPublished<Value> {

    /// publisher that stores the current Value and publishes changes
    private var state: CustomPublished<Value>.Publisher
    
    /// Storing the ObservableObjectPublisher from the enclosing ObservableObject
    private var change: ObservableObjectPublisher?
    
    /// Creates the published instance with an initial wrapped value.
    ///
    /// Don't use this initializer directly. Instead, create a property with the `@CustomPublished` attribute, as shown here:
    ///
    ///     @CustomPublished var lastUpdated: Date = Date()
    ///
    /// - Parameter wrappedValue: The publisher's initial value.
    init(wrappedValue value: Value) {
        self.state = CustomPublished.Publisher(value)
    }

    /// Getter and setter for the Value
    ///
    /// Setter Publishes Changes to the ObservalbeObject on the Main Thread
    var wrappedValue: Value {
        get {
            return state.value
        }
        set {
            DispatchQueue.main.async {
                self.change?.send()
            }
            state.send(newValue)
        }
    }

    /// The Publisher for the wrapped value.
    ///
    /// The ``CustomPublished/projectedValue`` is the property accessed with the `$` operator.
    var projectedValue: CustomPublished<Value>.Publisher {
        return state
    }

    /// Publisher that works similar to CurrentValueSubject but publishes changes before they are stored in the variable
    class Publisher: Combine.Publisher {
        typealias Output = Value
        typealias Failure = Never

        var value: Value {
            willSet {
                emitter.send(newValue)
            }
        }
        private var emitter = PassthroughSubject<Value, Never>()

        init(initialValue: Value) {
            self.value = initialValue
        }

        func receive<S>(subscriber: S) where Value == S.Input, S: Subscriber, S.Failure == Never {
            let subscription = Subscription(subscriber: subscriber, publisher: self)
            subscriber.receive(subscription: subscription)
        }

        private final class Subscription<S: Subscriber>: Combine.Subscription where S.Input == Output, S.Failure == Failure {
            private var subscriber: S?
            private var cancellable: AnyCancellable?
            init(subscriber: S, publisher: Publisher) {
                self.subscriber = subscriber
                _ = self.subscriber?.receive(publisher.value)
                cancellable = publisher.emitter.sink { value in
                    _ = self.subscriber?.receive(value)
                }
            }

            func cancel() {
                subscriber = nil
                cancellable?.cancel()
            }

            func request(_ demand: Subscribers.Demand) {}

        }

    }
    
    /// Subscript that gets called when property is changed.
    ///
    /// Saves the objectWillChange method for signaling changes to the enclosing ObservableObject.
    ///
    public static subscript<EnclosingSelf: ObservableObject>(
      _enclosingInstance object: EnclosingSelf,
      wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, T>,
      storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, CustomPublished<T>>
    ) -> T {
      get {
          return object[keyPath: storageKeyPath].wrappedValue
      }
      set {
          if let observable = (object as? (any ObservableObject)) {
              object[keyPath: storageKeyPath].change = observable.objectWillChange as! ObservableObjectPublisher
          }
          object[keyPath: storageKeyPath].wrappedValue = newValue
      }
    }
}
