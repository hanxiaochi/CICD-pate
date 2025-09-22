package com.example;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit test for simple App.
 */
public class AppTest {
    
    /**
     * Test that the application runs without throwing exceptions
     */
    @Test
    public void shouldExecuteApplicationWithoutException() {
        // This test verifies that the main method runs without throwing exceptions
        assertDoesNotThrow(() -> {
            App.main(new String[]{});
        });
    }
    
    /**
     * Test basic arithmetic to verify testing framework works
     */
    @Test
    public void shouldPassBasicArithmeticTest() {
        assertEquals(4, 2 + 2, "2 + 2 should equal 4");
        assertTrue(3 > 1, "3 should be greater than 1");
        assertFalse(1 > 3, "1 should not be greater than 3");
    }
    
    /**
     * Test string operations
     */
    @Test
    public void shouldProcessStringsCorrectly() {
        String greeting = "Hello";
        String target = "World";
        String message = greeting + ", " + target + "!";
        
        assertEquals("Hello, World!", message, "String concatenation should work correctly");
        assertTrue(message.contains("Hello"), "Message should contain 'Hello'");
    }
}