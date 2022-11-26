# Published PropertyWrapper

This Repository is supposed to show how you can create a custom PropertyWrapper that replicates the behaviour of the `@Published` PropertyWrapper provided in SwiftUI.
This example provides a publisher as a projected value which can be accessed via the `$` operator in front of the variable. Furthermore it can be used inside of an ObservableObject in MVVM Applications to have all the power of using the value as a `Binding`.

## Usage
The following example shows how the propertywrapper can be used to monitor changes to a variable:

```
class Weather {
    @CustomPublished var temperature: Double
    init(temperature: Double) {
        self.temperature = temperature
    }
}

let weather = Weather(temperature: 20)
let cancellable = weather.$temperature.sink() {
     print ("Temperature now: \($0)")
}
weather.temperature = 25 
```

Output: 

```
Temperature now: 20.0
Temperature now: 25.0
```


> **Warning**
> Values get emitted on willSet


### MVVM
This Example shows how the propertywrapper can be used to acchieve a binding between the variable and a textfield.

```
class ViewModel: ObservalbleObject {
    @CustomPublished var text = ""
}
```

```
struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()
    var body: some View {
        VStack {
            TextField("Input", text: $viewModel.text)
        }
    }
}
```

