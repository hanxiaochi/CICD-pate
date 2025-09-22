package com.example;

/**
 * A simple Java application for testing CICD pipeline
 */
public class App {
    public static void main(String[] args) {
        System.out.println("Hello, CICD World!");
        System.out.println("This is a test Java application.");
        
        // Print some system properties for demonstration
        System.out.println("Java Version: " + System.getProperty("java.version"));
        System.out.println("OS Name: " + System.getProperty("os.name"));
        
        // Simulate some work
        for (int i = 1; i <= 5; i++) {
            System.out.println("Processing step " + i + "...");
            try {
                Thread.sleep(1000); // Sleep for 1 second
            } catch (InterruptedException e) {
                System.err.println("Interrupted: " + e.getMessage());
            }
        }
        
        System.out.println("Application finished successfully!");
    }
}