<?php

namespace App\Exceptions;

use Exception;

/**
 * Thrown when the AI provider is unreachable, misconfigured, or returns a
 * response the generator cannot use — lets the controller return a
 * controlled error instead of a raw stack trace or a 500 crash.
 */
class AiProviderException extends Exception
{
}
