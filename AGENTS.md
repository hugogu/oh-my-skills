<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->

# System Design Rules

* Adopt eventually consistency by default. 
* Deployable via docker and K8S.
* Maintains horizontal scalability, prevent distributed lock.

# Implementation Rules
* Check existing code and library if existing implementation already available before writing a new one.
* Leveraging 3rd party library is prefered than implementing it again.
* If the same goal can be achived more easily after a refactoring, then do refactoring first with a standalone commit. 
* Maintain purity of Method and Functions and delay side effects. 
* Ensure testability and write unit tests for new code. 
* Ensure project build successfully after any new changes (include local docker build if available)
* Programming style should follows existing code. 

# API Design Rules
* API should be idempotent.
* RESTful style is prefered. 

# DB Changes Rules

* DB Schema changes must be performed via migration. NOT via running DDL against DB instance.
* Do not ever change business meaning/scope of an existing DB column, adding a new column is prefered than expanding scope of existing column.
