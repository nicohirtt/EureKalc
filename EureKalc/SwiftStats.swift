//
//  SwiftStats.swift
//
//  Thanks to Raphael Deem !!
//

import Foundation


/**
 Stats Statistical Functions
 
 This `struct` is used as a namespace to separate the stats functions in
 SwiftStats.
 
 In general, the functions here do not throw exceptions but `nil` values can be
 returned.  For example, to calculate the standard deviation of a sample
 requires at least two data points.  If the array that is passed to `sd()` does
 not have at least two values then `nil` is returned.
 
 Functions here are often generic in that they work for a range of types (for
 example, the same function is called to calculate the mean of Int8, Int32,
 Int64, or Int arrays).  Separate implementations can be found for BinaryInteger
 and BinaryFloatingPoint protocols.
 */

public struct Stats {
    private static let pi = Double.pi
    
    /**
     Calculate `n!` for values of `n` that conform to the BinaryInteger
     protocol.  Returns `nil` if `n` is less than zero.
     */
    public static func factorial<T: BinaryInteger>(_ n: T) -> Int? {
        if n < 0 {
            return nil
        }
        return Int(tgamma(Double(n+1)))
    }

    /**
     Calculate `n!` for values of `n` that conform to the BinaryFloatingPoint
     protocol.  Uses the gamma function to "fill in" values of `n` that are
     not integers.  Returns `nil` if `n` is less than zero.
     */
    public static func factorial<T: BinaryFloatingPoint>(_ n: T) -> Double? {
        if n < 0 {
            return nil
        }
        return Double(tgamma(Double(n+1)))
    }

    /**
     Calculate n-choose-k for values of `n` and `k` that conform to the BinaryInteger
     protocol.
     */
    public static func choose<T: BinaryInteger>(n: T, k: T) -> Int {
        return Int(tgamma(Double(n + 1)))/Int(tgamma(Double(k + 1))*tgamma(Double(n - k + 1)))
    }

    /**
     Calculate n-choose-k for values of `n` that conform to the BinaryFloatingPoint
     protocol and values of `k` that conform to the BinaryInteger protocol.
     */
    public static func choose<N: BinaryFloatingPoint, K: BinaryInteger>(n: N, k: K) -> Double {
        return Double(tgamma(Double(n + 1)))/Double(tgamma(Double(k + 1))*tgamma(Double(Double(n) - Double(k) + 1)))
    }

    
    /**
     Calculates the mean of an array of values for types that satisfy the
     BinaryInteger protocol (e.g Int, Int32).
     
     - Parameters:
        - data: Array of values
     
     - Returns:
        The mean of the array of values or `nil` if the array was empty.
     */
    public static func mean<T: BinaryInteger>(_ data: [T]) -> Double? {
        if data.count == 0 {
            return nil
        }
        return Double(data.reduce(0, +))/Double(data.count)
    }

    /**
     Calculates the mean of an array of values for types that satisfy the
     BinaryFloatingPoint protocol (e.g Float, Double).
     
     - Parameters:
        - data: Array of values
     
     - Returns:
     The mean of the array of values or `nil` if the array was empty.
     */
    public static func mean<T : BinaryFloatingPoint>(_ data: [T]) -> Double? {
        if data.count == 0 {
            return nil
        }
        return Double(data.reduce(0, +))/Double(data.count)
    }

    
    /**
     Calculates the unbiased sample variance for an array for types that satisfy
     the BinaryFloatingPoint protocol (e.g Float, Double).
     
     - Parameters:
        - data:
        Sample of values.  Note that this should contain at least two values.
     
     - Returns:
        The unbiased sample variance or `nil` if `data` contains fewer than two
        values.
     */
    public static func variance<T: BinaryFloatingPoint>(_ data: [T]) -> Double? {
        if data.count < 2 {
            return nil
        }
        
        guard let m = mean(data) else {
            return nil // This shouldn't ever occur
        }
        var total = 0.0
        for i in 0..<data.count {
            total += pow(Double(data[i]) - m,2)
        }
        return total/Double(data.count-1)
    }
    
    /**
     Calculates the unbiased sample standard deviation for an array of values
     for types that satisfy the BinaryFloatingPoint protocol (e.g Float, Double).
     
     - Parameters:
        - data:
        Sample of values.  Note that this should contain at least two values.
     
     - Returns:
        The sample unbiased standard deviation or `nil` if `data` contains fewer
        than two values.
     */
    public static func sd<T: BinaryFloatingPoint>(_ data: [T]) -> Double? {
        guard let v = variance(data) else {
            return nil
        }
        return sqrt(v)
    }
    
    /**
     Calculates the unbiased sample standard deviation for an array of values
     for types that satisfy the BinaryInteger protocol (e.g Int, Int32).
     
     - Parameters:
        - data:
        Sample of values.  Note that this should contain at least two values.
     
     - Returns:
     The sample unbiased standard deviation or `nil` if `data` contains fewer
     than two values.
     */
    public static func sd<T: BinaryInteger>(_ data: [T]) -> Double? {
        guard let v = variance(data) else {
            return nil
        }
        return sqrt(v)
    }

    /**
     Calculates the population variance for an array of values for types that
     satisfy the BinaryFloatingPoint protocol (e.g Float, Double).
     
     - Parameters:
        - data:
        Values of population.  Note that this should contain at least one value.
     
     - Returns:
     The population variance or `nil` if `data` contains fewer than one value.
     */
    public static func pvariance<T: BinaryFloatingPoint>(_ data: [T]) -> Double? {
        if data.count < 1 {
            return nil
        }
        guard let m = mean(data) else {
            return nil // This shouldn't ever occur
        }
        var total = 0.0
        for i in 0..<data.count {
            total += pow(Double(data[i]) - m,2)
        }
        return total/Double(data.count)
    }

    /**
     Calculates the unbiased sample variance for an array of values for types
     that satisfy the BinaryInteger protocol (e.g Int, Int32).
     
     - Parameters:
        - data:
        Sample of values.  Note that this should contain at least two values.
     
     - Returns:
     The unbiased sample variance or `nil` if `data` contains fewer than two
     values.
     */
    public static func variance<T: BinaryInteger>(_ data: [T]) -> Double? {
        if data.count < 2 {
            return nil
        }
        
        guard let m = mean(data) else {
            return nil // This shouldn't ever occur
        }
        var total = 0.0
        for i in 0..<data.count {
            total += pow(Double(data[i]) - m,2)
        }
        return total/Double(data.count-1)
    }

    /**
     Calculates the population variance for an array of values for types that
     satisfy the BinaryInteger protocol (e.g Int, Int32).
     
     - Parameters:
        - data:
        Values of population.  Note that this should contain at least one value.
     
     - Returns:
     The population variance or `nil` if `data` contains fewer than one value.
     */
    public static func pvariance<T: BinaryInteger>(_ data: [T]) -> Double? {
        guard let m = mean(data) else {
            return nil
        }
        var total = 0.0
        for i in 0..<data.count {
            total += pow(Double(data[i]) - m,2)
        }
        return total/Double(data.count)
    }
    
    /**
     Calculates the median of an array of values for types that
     satisfy the BinaryFloatingPoint protocol (e.g Float, Double).
     
     - Parameters:
        - data:
        Values of population.  Note that this should contain at least one value.
     
     - Returns:
     The population variance or `nil` if `data` contains fewer than one value.
     */
    public static func median<T: BinaryFloatingPoint>(_ data: [T]) -> Double? {
        if data.isEmpty {
            return nil
        }
        let sorted_data = data.sorted()
        if data.count % 2 == 1 {
            return Double(sorted_data[Int(floor(Double(data.count)/2))])
        }
        else {
            return Double(sorted_data[data.count/2]+sorted_data[(data.count/2)-1])/2
        }
    }
    
    /**
     Calculates the median of an array of values for types that
     satisfy the BinaryInteger protocol (e.g Int, Int32).
     
     - Parameters:
        - data:
        Values of population.  Note that this should contain at least one value.
     
     - Returns:
     The population variance or `nil` if `data` contains fewer than one value.
     */
    public static func median<T: BinaryInteger>(_ data: [T]) -> Double? {
        if data.isEmpty {
            return nil
        }
        let sorted_data = data.sorted()
        if data.count % 2 == 1 {
            return Double(sorted_data[Int(floor(Double(data.count)/2))])
        }
        else {
            return Double(sorted_data[data.count/2]+sorted_data[(data.count/2)-1])/2
        }
    }

   
    public static func erfinv(_ y: Double) -> Double {
        let center = 0.7
        let a = [ 0.886226899, -1.645349621,  0.914624893, -0.140543331]
        let b = [-2.118377725,  1.442710462, -0.329097515,  0.012229801]
        let c = [-1.970840454, -1.624906493,  3.429567803,  1.641345311]
        let d = [ 3.543889200,  1.637067800]
        if abs(y) <= center {
            let z = pow(y,2)
            let num = (((a[3]*z + a[2])*z + a[1])*z) + a[0]
            let den = ((((b[3]*z + b[2])*z + b[1])*z + b[0])*z + 1.0)
            var x = y*num/den
            x = x - (erf(x) - y)/(2.0/sqrt(pi)*exp(-x*x))
            x = x - (erf(x) - y)/(2.0/sqrt(pi)*exp(-x*x))
            return x
        }

        else if abs(y) > center && abs(y) < 1.0 {
            let z = pow(-log((1.0-abs(y))/2),0.5)
            let num = ((c[3]*z + c[2])*z + c[1])*z + c[0]
            let den = (d[1]*z + d[0])*z + 1
            // should use the sign public static function instead of pow(pow(y,2),0.5)
            var x = y/pow(pow(y,2),0.5)*num/den
            x = x - (erf(x) - y)/(2.0/sqrt(pi)*exp(-x*x))
            x = x - (erf(x) - y)/(2.0/sqrt(pi)*exp(-x*x))
            return x
        }

        else if abs(y) == 1 {
            return y*Double(Int.max)
        }

        else {
            // this should throw an error instead
            return Double.nan
        }
    }

    public static func lsr(_ points: [[Double]]) -> [Double] {
        var total_x = 0.0
        var total_xy = 0.0
        var total_y = 0.0
        var total_x2 = 0.0
        for i in 0..<points.count {
            total_x += points[i][0]
            total_y += points[i][1]
            total_xy += points[i][0]*points[i][1]
            total_x2 += pow(points[i][0], 2)
        }
        let N = Double(points.count)
        let b = (N*total_xy - total_x*total_y)/(N*total_x2 - pow(total_x, 2))
        let a = (total_y - b*total_x)/N
        return [a, b]
    }

}


/**
 Protocol for discrete distributions.
 
 Defines the `quantile()` method that must be implemented.
 */
public protocol DiscreteDistribution {
    func quantile(_ p: Double) -> Int
}

extension DiscreteDistribution {
    /**
     Single discrete random value using a user-provided random number generator
     
     - Parameters:
       - using: A random number generator
     
     - Returns:
     A random number from the distribution represented by the instance
     */
    public func random<T: RandomNumberGenerator>(using generator: inout T) -> Int {
        let x = Double.random(in: 0.0...1.0,
                              using: &generator)
        return quantile(x)
    }
    
    /**
     Single discrete random value using the system random number generator
     
     - Returns:
     A random number from the distribution represented by the instance
     */
    public func random() -> Int {
        var rng = SystemRandomNumberGenerator()
        return random(using: &rng)
    }
    
    /**
     Array of discrete random values
     - Parameter n: number of values to produce
     - Complexity: O(n)
     */
    public func random(_ n: Int) -> [Int] {
        var results: [Int] = []
        for _ in 0..<n {
            results.append(random())
        }
        return results
    }

}

/**
 Protocol for continuous distributions.
 
 Defines the `quantile()` method that must be implemented.
 */
public protocol ContinuousDistribution {
    func quantile(_ p: Double) -> Double
}


extension ContinuousDistribution {
    /**
     Single discrete random value using a user-provided random number generator
     
     - Parameters:
       - using: A random number generator
     
     - Returns:
     A random number from the distribution represented by the instance
     */
    public func random<T: RandomNumberGenerator>(using generator: inout T) -> Double {
        let x = Double.random(in: 0.0...1.0,
                              using: &generator)
        return quantile(x)
    }
    
    
    /**
     Single discrete random value using the system random number generator
     
     - Returns:
     A random number from the distribution represented by the instance
     */
    public func random() -> Double {
        var rng = SystemRandomNumberGenerator()
        return random(using: &rng)
    }
    
    
    /**
     Array of discrete random values
     - Parameter n: number of values to produce
     - Complexity: O(n)
     */
    public func random(_ n: Int) -> [Double] {
        var results: [Double] = []
        for _ in 0..<n {
            results.append(random())
        }
        return results
    }

}


public struct Distributions {
    private static let pi = Double.pi
    

    public class Bernoulli: DiscreteDistribution {
        var p: Double
        
        public init(p: Double) {
            self.p = p
        }
        
        public convenience init?<T: BinaryInteger>(data: [T]) {
            guard let m = Stats.mean(data) else {
                return nil
            }
            self.init(p: m)
        }
        
        public func pmf(_ k: Int) -> Double {
            if k == 1 {
                return self.p
            }
            if k == 0 {
                return 1 - self.p
            }
            return -1
        }
        
        public func cdf(_ k: Int) -> Double {
            if k < 0 {
                return 0
            }

            if k < 1 {
                return 1 - self.p
            }
            if k >= 1 {
                return 1
            }
            return -1
        }
        
        public func quantile(_ p: Double) -> Int {
            if p < 0 {
                return -1
            }
            else if p < 1 - self.p {
                return 0
            }
            else if p <= 1 {
                return 1
            }
            return -1
        }
    }

    public class Laplace: ContinuousDistribution {
        var mean: Double
        var b: Double

        public init (mean: Double, b: Double) {
            self.mean = mean
            self.b = b
        }

        public convenience init?(data: [Double]) {
            guard let m = Stats.median(data) else {
                return nil
            }
            var b = 0.0
            for i in 0..<data.count {
                b += abs(data[i] - m)
            }
            b = b/Double(data.count)
            self.init(mean: m, b: b)
        }

        public func pdf(_ x: Double) -> Double {
            return exp(-abs(x - self.mean)/self.b)/2
        }

        public func cdf(_ x: Double) -> Double {
            if x < self.mean {
                return exp((x - self.mean)/self.b)/2
            }
            else if x >= self.mean {
                return 1 - exp((self.mean - x)/self.b)/2
            }
            else {
                return -1
            }
        }

        public func quantile(_ p: Double) -> Double {
            if p > 0 && p <= 0.5 {
                return self.mean + self.b*log(2*p)
            }
            if p > 0.5 && p < 1 {
                return self.mean - self.b*log(2*(1-p))
            }
            return -1
        }
    }

    public class Poisson: DiscreteDistribution {
        var m: Double
        public init(m: Double) {
            self.m = m
        }

        public convenience init?(data: [Double]) {
            guard let m = Stats.mean(data) else {
                return nil
            }
            self.init(m: m)
        }

        public func pmf(_ k: Int) -> Double {
            return exp(Double(k) * log(m) - m - lgamma(Double(k+1)))
        }

        public func cdf(_ k: Int) -> Double {
            var total = Double(0)
            for i in 0..<k+1 {
                total += self.pmf(i)
            }
            return total
        }

        public func quantile(_ x: Double) -> Int {
            var total = Double(0)
            var j = 0
            total += self.pmf(j)
            while total < x {
                j += 1
                total += self.pmf(j)
            }
            return j
        }
    }

    public class Geometric: DiscreteDistribution {
        var p: Double
        public init(p: Double) {
            self.p = p
        }

        public convenience init?(data: [Double]) {
            guard let m = Stats.mean(data) else {
                return nil
            }
            self.init(p: 1/m)
        }

        public func pmf(_ k: Int) -> Double {
            return pow(1 - self.p, Double(k - 1))*self.p
        }

        public func cdf(_ k: Int) -> Double {
            return 1 - pow(1 - self.p, Double(k))
        }

        public func quantile(_ p: Double) -> Int {
            return Int(ceil(log(1 - p)/log(1 - self.p)))
        }
    }

    public class Exponential: ContinuousDistribution {
        var l: Double
        public init(l: Double) {
            self.l = l
        }

        public convenience init?(data: [Double]) {
            guard let m = Stats.mean(data) else {
                return nil
            }
            self.init(l: 1/m)
        }

        public func pdf(_ x: Double) -> Double {
            return self.l*exp(-self.l*x)
        }

        public func cdf(_ x: Double) -> Double {
            return 1 - exp(-self.l*x)
        }

        public func quantile(_ p: Double) -> Double {
            return -log(1 - p)/self.l
        }
    }

    public class Binomial: DiscreteDistribution {
        var n: Int
        var p: Double
        public init(n: Int, p: Double) {
            self.n = n
            self.p = p
        }

        public func pmf(_ k: Int) -> Double {
            let r = Double(k)
            return Double(Stats.choose(n: self.n, k: k))*pow(self.p, r)*pow(1 - self.p, Double(self.n - k))
        }
        
        public func cdf(_ k: Int) -> Double {
            var total = Double(0)
            for i in 1..<k + 1 {
                total += self.pmf(i)
            }
            return total
        }
        
        public func quantile(_ x: Double) -> Int {
            var total = Double(0)
            var j = 0
            while total < x {
                j += 1
                total += self.pmf(j)
            }
            return j
        }
    }

    public class Normal: ContinuousDistribution {
        // mean and variance
        var m: Double
        var v: Double

        public init(m: Double, v: Double) {
            self.m = m
            self.v = v
        }
        
        public convenience init(mean: Double, sd: Double) {
            // This contructor takes the mean and standard deviation, which is the more
            // common parameterisation of a normal distribution.
            let variance = pow(sd, 2)
            self.init(m: mean, v: variance)
        }

        public convenience init?(data: [Double]) {
            // this calculates the mean twice, since variance()
            // uses the mean and calls mean()
            guard let v = Stats.variance(data) else {
                return nil
            }
            guard let m = Stats.mean(data) else {
                return nil // This shouldn't ever occur
            }
            self.init(m: m, v: v)
        }

        public func pdf(_ x: Double) -> Double {
            return (1/pow(self.v*2*pi,0.5))*exp(-pow(x-self.m,2)/(2*self.v))
        }

        public func cdf(_ x: Double) -> Double {
            return (1 + erf((x-self.m)/pow(2*self.v,0.5)))/2
        }

        public func quantile(_ p: Double) -> Double {
            return self.m + pow(self.v*2,0.5)*Stats.erfinv(2*p - 1)
        }
    }
    
    /**
     The Maxwell-Boltzmann distribution.
     */
    public class Boltzmann: ContinuousDistribution {
        // a=sqrt(k.T/m)
        var a: Double
        var quants: [Double]
        
        /**
         Constructor
         */
        public init(a: Double) {
            let nx=2000
            let nq=1000
            let max=a*20.0
            self.a = a
            let x = Array(0...nx).map({ Double($0)*max/Double(nx) })
            let cd = x.map({ erf($0/(sqrt(2)*a))-sqrt(2/pi)*$0*exp(-pow($0,2)/(2*pow(a,2)))/a })
            var xq : [Double] = []
            for j in 0...nq {
                let q = Double(j)/Double(nq)
                if q == 0 {
                    xq = [0]
                } else {
                    
                    if q < cd[0] {
                        xq.append(0)
                    } else if q >= 1 {
                        xq.append(a*1000000)
                    } else {
                        let i = cd.firstIndex(where: {$0>q})!
                        xq.append((x[i]-x[i-1])/(cd[i]-cd[i-1])*(q-cd[i-1])+x[i-1])
                         
                    }
                    
                }
            }
            
            self.quants = xq // les quantiles 0, 0.01, 0.02... 1
        }
        
        
        public func pdf(_ x: Double) -> Double {
            return sqrt(2/pi)*pow(x,2)*exp(-pow(x,2)/(2*pow(a,2)))/pow(a,3)
        }
        
        public func cdf(_ x: Double) -> Double {
            return erf(x/sqrt(2*a))-sqrt(2/pi)*x*exp(-pow(x,2)/(2*pow(a,2)))/a
        }
        
        public func quantile(_ p: Double) -> Double {
            let nq=1000.0
            if p == 0.0 {
                return 0
            }
            if p == 1.0 {
                return quants.last!
            }
            let n = Int(p*nq)
            let q = quants[n]+(quants[n+1]-quants[n])*(p-Double(n)/nq)
            return q
        }

    }
    
    /**
     The log-normal continuous distribution.
     
     Three constructors are provided.
     
     There are two parameter-based constructors; both take the mean of the
     distribution on the log scale.  One constructor takes the variance of
     the distribution on the log scale, and the other takes the standard
     deviation on the log scale.  See `LogNormal.init(meanLog:varianceLog:)` and
     `LogNormal.init(meanLog:sdLog:)`.
     
     One data-based constructor is provided.  Given an array of sample values,
     a log-normal distribution will be created parameterised by the mean and
     variance of the sample data.
    */
    public class LogNormal: ContinuousDistribution {
        // Mean and variance
        var m: Double
        var v: Double
        
        /**
         Constructor that takes the mean and the variance of the distribution
         under the log scale.
         */
        public init(meanLog: Double, varianceLog: Double) {
            self.m = meanLog
            self.v = varianceLog
        }
        
        /**
         Constructor that takes the mean and the standard deviation of the
         distribution under the log scale.
         */
        public convenience init(meanLog: Double, sdLog: Double) {
            // This contructor takes the mean and standard deviation, which is
            // the more common parameterisation of a log-normal distribution.
            let varianceLog = pow(sdLog, 2)
            self.init(meanLog: meanLog, varianceLog: varianceLog)
        }
        
        /**
         Constructor that takes sample data and uses the the mean and the
         standard deviation of the sample data under the log scale.
         */
        public convenience init?(data: [Double]) {
            // This calculates the mean twice, since variance()
            // uses the mean and calls mean()
            // Create an array of Doubles the same length as data
            var logData = [Double](repeating: 0, count: data.count)
            
            // Find the log of all the values in the array data
            for i in stride(from: 0, to: data.count, by: 1) {
                logData[i] = log(data[i])
            }
            
            guard let v = Stats.variance(logData) else {
                return nil
            }
            
            guard let m = Stats.mean(logData) else {
                return nil // This shouldn't ever occur
            }
        
            self.init(meanLog: m,
                      varianceLog: v)
        }
        
        public func pdf(_ x: Double) -> Double {
            return 1/(x*sqrt(2*pi*v)) * exp(-pow(log(x)-m,2)/(2*v))
        }
        
        public func cdf(_ x: Double) -> Double {
            return 0.5 + 0.5*erf((log(x)-m)/sqrt(2*v))
        }
        
        public func quantile(_ p: Double) -> Double {
            return exp(m + sqrt(2*v)*Stats.erfinv(2*p - 1))
        }

    }

    public class Uniform: ContinuousDistribution {
        // a and b are endpoints, that is
        // values will be distributed uniformly between points a and b
        var a: Double
        var b: Double

        public init(a: Double, b: Double) {
            self.a = a
            self.b = b
        }

        public func pdf(_ x: Double) -> Double {
            if x>a && x<b {
                return 1/(b-a)
            }
            return 0
        }

        public func cdf(_ x: Double) -> Double {
            if x<a {
                return 0
            }
            else if x<b {
                return (x-a)/(b-a)
            }
            else if x>=b {
                return 1
            }
            return 0
        }

        public func quantile(_ p: Double) -> Double {
            if p>=0 && p<=1{
                return p*(b-a)+a
            }
            return Double.nan
        }
    }
}
