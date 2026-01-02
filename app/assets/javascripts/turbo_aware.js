// Turbo-Aware JavaScript Utilities
// Provides patterns for JavaScript that works with Turbo Streams and dynamic DOM updates

(function() {
  'use strict';

  // Helper to run code on both initial load and Turbo updates
  window.TurboAware = {
    // Run a function on page load and after Turbo updates
    onLoad: function(callback) {
      // Run immediately if DOM is already loaded
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', callback);
      } else {
        // Use setTimeout to ensure DOM is ready
        setTimeout(callback, 0);
      }

      // Run on Turbo navigation
      document.addEventListener('turbo:load', callback);
      
      // Run after Turbo Stream renders
      document.addEventListener('turbo:frame-load', function(event) {
        setTimeout(callback, 50);
      });
      
      document.addEventListener('turbo:after-stream-render', function() {
        // Small delay to ensure DOM is fully updated
        setTimeout(callback, 50);
      });

      // Also listen for turbo:submit-end
      document.addEventListener('turbo:submit-end', function(event) {
        if (event.detail && event.detail.success !== false) {
          setTimeout(callback, 100);
        }
      });
    },

    // Run a function only after Turbo Stream updates (not on initial load)
    onStreamUpdate: function(callback) {
      document.addEventListener('turbo:after-stream-render', function() {
        setTimeout(callback, 50);
      });
      document.addEventListener('turbo:frame-load', function() {
        setTimeout(callback, 50);
      });
    },

    // Event delegation helper - attach listener to document that works with dynamic content
    delegate: function(eventType, selector, handler) {
      document.addEventListener(eventType, function(event) {
        const target = event.target.closest(selector);
        if (target) {
          handler.call(target, event);
        }
      }, true); // Use capture phase for better delegation
    },

    // Query selector that re-queries on each call (for dynamic content)
    // Always queries fresh from DOM - never caches
    query: function(selector, context) {
      context = context || document;
      return context.querySelector(selector);
    },

    // Query all that re-queries on each call
    queryAll: function(selector, context) {
      context = context || document;
      return Array.from(context.querySelectorAll(selector));
    },

    // Safe getElementById that re-queries on each call
    getElement: function(id) {
      return document.getElementById(id);
    },

    // Watch for element changes using MutationObserver
    watch: function(selector, callback, options) {
      options = options || { childList: true, subtree: true };
      
      const observer = new MutationObserver(function(mutations) {
        const element = document.querySelector(selector);
        if (element) {
          callback(element, mutations);
        }
      });

      // Start observing
      const element = document.querySelector(selector);
      if (element) {
        observer.observe(document.body, options);
        callback(element, []);
      }

      // Re-observe after Turbo updates
      const reobserve = function() {
        const element = document.querySelector(selector);
        if (element) {
          observer.disconnect();
          observer.observe(document.body, options);
          callback(element, []);
        }
      };

      document.addEventListener('turbo:after-stream-render', reobserve);
      document.addEventListener('turbo:frame-load', reobserve);

      return observer;
    },

    // Initialize form fields that may be replaced by Turbo Streams
    initFormFields: function(formSelector, callback) {
      const initFields = function() {
        const form = document.querySelector(formSelector);
        if (form) {
          callback(form);
        }
      };

      this.onLoad(initFields);
    },

    // Initialize buttons/actions that may be replaced
    initActions: function(selector, callback) {
      const init = function() {
        const elements = Array.from(document.querySelectorAll(selector));
        elements.forEach(callback);
      };

      this.onLoad(init);
    },

    // Debounce helper for search inputs
    debounce: function(func, wait) {
      let timeout;
      return function executedFunction(...args) {
        const later = function() {
          clearTimeout(timeout);
          func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
      };
    }
  };

  // Global helper for common patterns
  window.onTurboLoad = function(callback) {
    TurboAware.onLoad(callback);
  };

  window.onTurboStream = function(callback) {
    TurboAware.onStreamUpdate(callback);
  };

  // Override common DOM methods to be Turbo-aware
  // This ensures that when code uses getElementById, it always gets fresh elements
  const originalGetElementById = document.getElementById.bind(document);
  document.getElementById = function(id) {
    // Always query fresh - don't cache
    return originalGetElementById(id);
  };

})();

