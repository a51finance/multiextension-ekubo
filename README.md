# Multiextension

Ekubo extensions allow developers to build custom AMMs or creative solutions on top of the Ekubo protocol by developing extensions. Ekubo pools can be initialized with an extension that implements specific functionality, which is then called by the Ekubo core during each method lifecycle.

However, one limitation of extensions is that they cannot be changed once they are configured with Ekubo. While this can be mitigated by creating an upgradable extension contract, what if you want to combine multiple extensions within one extension?

This is where **Multiextension** comes into play. It enables developers to support multiple extensions within a single Ekubo pool. The core pool is initialized with a multiextension contract, which then manages the execution of additional sub-extensions.

# Features

- Supports up to 16 extensions.
- Allows developers to define the execution order of each extension's lifecycle methods. For example, Extension A's "before init" method can be called before Extension B's, while their "after init" methods can execute in reverse order.
- Provides the ability to enable or disable specific methods of an extension.
