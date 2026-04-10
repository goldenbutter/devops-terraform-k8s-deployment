// Package services contains business logic separated from HTTP transport.
// This keeps handlers thin and makes the logic independently testable.
package services

import (
	"math"
	"time"
)

// CalcResult holds the output of a CPU-intensive prime-number computation.
// It reports how many primes were found and how long the work took.
type CalcResult struct {
	Primes   int           `json:"primes_found"`
	Limit    int           `json:"limit"`
	Duration time.Duration `json:"computation_time"`
}

// CalculatePrimes finds all prime numbers up to the given limit using a
// trial-division algorithm. The work is intentionally CPU-heavy so that
// Kubernetes HPA can observe the CPU spike and scale the deployment.
func CalculatePrimes(limit int) CalcResult {
	start := time.Now()
	count := 0

	for n := 2; n <= limit; n++ {
		if isPrime(n) {
			count++
		}
	}

	return CalcResult{
		Primes:   count,
		Limit:    limit,
		Duration: time.Since(start),
	}
}

// isPrime checks whether n is a prime number by testing divisibility up to
// its square root. This is O(√n) per call — fast enough for correctness but
// slow enough in aggregate to generate meaningful CPU load.
func isPrime(n int) bool {
	if n < 2 {
		return false
	}
	if n == 2 {
		return true
	}
	if n%2 == 0 {
		return false
	}
	sqrtN := int(math.Sqrt(float64(n)))
	for i := 3; i <= sqrtN; i += 2 {
		if n%i == 0 {
			return false
		}
	}
	return true
}
