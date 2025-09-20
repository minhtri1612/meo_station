import logger from './logger';

// Simple in-memory metrics store (in production, use Redis or external service)
class MetricsCollector {
  private metrics: Map<string, number> = new Map();
  private timers: Map<string, number> = new Map();

  // Increment a counter
  increment(metric: string, value: number = 1) {
    const current = this.metrics.get(metric) || 0;
    this.metrics.set(metric, current + value);
    logger.info(`Metric incremented: ${metric} = ${current + value}`);
  }

  // Set a gauge value
  gauge(metric: string, value: number) {
    this.metrics.set(metric, value);
    logger.info(`Metric gauge set: ${metric} = ${value}`);
  }

  // Start timing
  startTimer(metric: string) {
    this.timers.set(metric, Date.now());
  }

  // End timing and record duration
  endTimer(metric: string) {
    const startTime = this.timers.get(metric);
    if (startTime) {
      const duration = Date.now() - startTime;
      this.gauge(`${metric}_duration_ms`, duration);
      this.timers.delete(metric);
      logger.info(`Timer completed: ${metric} took ${duration}ms`);
    }
  }

  // Get all metrics
  getMetrics() {
    return Object.fromEntries(this.metrics);
  }

  // Reset metrics (useful for testing)
  reset() {
    this.metrics.clear();
    this.timers.clear();
  }
}

// Create singleton instance
export const metrics = new MetricsCollector();

// Performance monitoring middleware
export const performanceMiddleware = (req: any, res: any, next: any) => {
  const startTime = Date.now();
  const path = req.url || req.path || 'unknown';
  
  // Increment request counter
  metrics.increment(`requests_total_${path}`);
  metrics.increment('requests_total');

  // Monitor response time
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    metrics.gauge(`response_time_${path}`, duration);
    metrics.gauge('response_time_avg', duration);
    
    // Log slow requests
    if (duration > 1000) {
      logger.warn(`Slow request detected: ${path} took ${duration}ms`);
    }
    
    // Track status codes
    metrics.increment(`status_${res.statusCode}`);
  });

  next();
};

// Database monitoring
export const monitorDatabase = async (operation: string, fn: () => Promise<any>) => {
  metrics.startTimer(`db_${operation}`);
  try {
    const result = await fn();
    metrics.increment(`db_${operation}_success`);
    return result;
  } catch (error) {
    metrics.increment(`db_${operation}_error`);
    logger.error(`Database error in ${operation}:`, error);
    throw error;
  } finally {
    metrics.endTimer(`db_${operation}`);
  }
};

// Business metrics tracking
export const trackOrder = (orderValue: number) => {
  metrics.increment('orders_total');
  metrics.increment('revenue_total', orderValue);
  metrics.gauge('avg_order_value', orderValue);
  logger.info(`Order tracked: $${orderValue}`);
};

export const trackProductView = (productId: string) => {
  metrics.increment(`product_views_${productId}`);
  metrics.increment('product_views_total');
};

export const trackCartAction = (action: 'add' | 'remove' | 'checkout') => {
  metrics.increment(`cart_${action}`);
  logger.info(`Cart action tracked: ${action}`);
};


