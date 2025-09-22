# Test Java Application

This is a simple Java application created for testing CICD pipelines.

## Project Structure

```
test-java-project/
├── pom.xml
├── README.md
├── src/
│   ├── main/
│   │   └── java/
│   │       └── com/example/
│   │           └── App.java
│   └── test/
│       └── java/
│           └── com/example/
│               └── AppTest.java
```

## Prerequisites

- Java 11 or higher
- Maven 3.6 or higher

## Build

To build the project, run:

```bash
mvn clean package
```

This will compile the code, run tests, and create a JAR file in the `target/` directory.

## Run

To run the application:

```bash
java -jar target/test-java-app-1.0.0.jar
```

Or using Maven:

```bash
mvn exec:java
```

## Test

To run tests:

```bash
mvn test
```

## Features

This simple application demonstrates:

1. Basic Java application structure
2. Maven build configuration
3. JUnit 5 testing
4. Executable JAR creation with main class manifest

The application will:
1. Print a greeting message
2. Display system information
3. Simulate work with a simple loop
4. Complete with a success message

## CICD Testing

This project can be used to test CICD pipeline functionality including:
- Source code checkout
- Dependency resolution
- Compilation
- Testing
- Packaging
- Artifact generation