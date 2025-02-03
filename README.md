# Multiextension

Ekubo extensions allow developers to build custom AMMs or creative solutions on top of the Ekubo protocol by developing extensions. Ekubo pools can be initialized with an extension that implements specific functionality, which is then called by the Ekubo core during each method lifecycle.

However, one limitation of extensions is that they cannot be changed once they are configured with Ekubo. While this can be mitigated by creating an upgradable extension contract, what if you want to combine multiple extensions within one extension?

This is where **Multiextension** comes into play. It enables developers to support multiple extensions within a single Ekubo pool. The core pool is initialized with a multiextension contract, which then manages the execution of additional sub-extensions.

# Features

- Supports up to 16 extensions.
- Allows developers to define the execution order of each extension's lifecycle methods. For example, Extension A's "before init" method can be called before Extension B's, while their "after init" methods can execute in reverse order.
- Provides the ability to enable or disable specific methods of an extension.
- Ownable contract only owner of Multiextension have rights to set and change extensions.

# A51 Finance

A51 Carbon on Starknet is the next-generation AMM for liquidity provisioning built on Ekubo. Imagine an AMM for LPs where they can use any arbitrary permutation of extensions to initialize a pool that works for them.

To learn more about it, follow A51 Finance [docs](https://docs.a51.finance/carbon).

### Purpose of Multiextension

A51 Carbon will come with A51-built intents for the most popular use cases with LPs having the ability to write and execute their own logic too within their pools.

These intents are created by combining multiple sub-extensions under a single Multiextension contract.

# Development

Multiextension uses [Scarb](https://docs.swmansion.com/scarb/docs) for development and testing purposes, and [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/index.html) as a toolchain to test contracts on mainnet forks.

### Prepare Environment

Simply install [Cairo and scarb](https://docs.swmansion.com/scarb/download).

### Build Contracts

```bash
scarb build
```

### Test Contracts

```bash
scarb test
```

# License

Multiextension contract is released under the [MIT License](https://github.com/a51finance/multiextension-ekubo/blob/main/LICENSE).
