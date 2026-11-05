/** An argument was invalid (C# ArgumentException). */
export class ArgumentError extends Error {
  constructor(message: string, readonly paramName?: string) {
    super(paramName === undefined ? message : `${message} (Parameter '${paramName}')`);
    this.name = "ArgumentError";
  }
}

/** An argument lay outside its allowed range (C# ArgumentOutOfRangeException). */
export class ArgumentOutOfRangeError extends ArgumentError {
  constructor(paramName: string, message = "Specified argument was out of the range of valid values.") {
    super(message, paramName);
    this.name = "ArgumentOutOfRangeError";
  }
}

/** The call is not valid for this object's state or kind (C# InvalidOperationException). */
export class InvalidOperationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidOperationError";
  }
}
