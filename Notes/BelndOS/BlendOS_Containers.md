
#### Creating containers
```
user create-container development ubuntu-22.04
```

#### Removing containers
```
user remove-container development
```

#### Entering containers
```
user shell my-first-container
```

#### Creating associations
```
user associate apt my-first-container
```
install a package with `sudo apt install [pkg]`

#### Deleting associations
```
user dissociate apt
```

#### Installing packages
```
user install my-first-container [pkg]
```

#### Removing packages
```
user remove my-first-container [pkg]
```

