package corobs

import "errors"

var (
	// ErrOutOfRange: an argument lies outside the values the operation accepts (C# ArgumentOutOfRangeException).
	ErrOutOfRange = errors.New("corobs: argument out of range")
	// ErrArgument: an argument is unusable as given (C# ArgumentException).
	ErrArgument = errors.New("corobs: invalid argument")
	// ErrInvalidOperation: the call does not apply to this object (C# InvalidOperationException).
	ErrInvalidOperation = errors.New("corobs: invalid operation")
)
