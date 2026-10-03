// Shared host publication primitive. Numeric values are not measurements here:
// they are already-observed values whose binary representation must survive.
using System;
using System.Collections;
using System.Globalization;
using System.IO;
using System.Management.Automation;
using System.Numerics;
using System.Text;
using System.Text.Json;

namespace SporeSpore.ProcessTransport
{
    public static class ExactJsonV1
    {
        private const int StringSegmentCharacters = 1024 * 1024;
        private delegate void StringSegmentWriter(ReadOnlySpan<char> value, bool isFinalSegment);
        // Reflection preserves loading on older hosts. Their existing small-
        // string path is unchanged; the current pinned host supplies this API.
        private static readonly System.Reflection.MethodInfo SegmentMethod =
            typeof(Utf8JsonWriter).GetMethod("WriteStringValueSegment",
                new Type[] { typeof(ReadOnlySpan<char>), typeof(bool) });

        private static void StringValue(Utf8JsonWriter writer, string value)
        {
            CheckedString(value);
            if (value.Length <= StringSegmentCharacters || SegmentMethod == null)
            {
                writer.WriteStringValue(value);
                return;
            }
            var append = (StringSegmentWriter)SegmentMethod.CreateDelegate(typeof(StringSegmentWriter), writer);
            for (int start = 0; start < value.Length;)
            {
                int count = Math.Min(StringSegmentCharacters, value.Length - start);
                // Keep a UTF-16 surrogate pair in one segment. The complete
                // input has already passed strict validation above.
                if (start + count < value.Length && char.IsHighSurrogate(value[start + count - 1]))
                    --count;
                append(value.AsSpan(start, count), start + count == value.Length);
                start += count;
            }
        }

        public static string Serialize(object value, int maximumDepth, bool indented)
        {
            if (maximumDepth < 1 || maximumDepth > 128)
                throw new ArgumentOutOfRangeException(nameof(maximumDepth));
            using (var stream = new MemoryStream())
            {
                using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions {
                    Indented = indented, MaxDepth = maximumDepth
                }))
                {
                    Write(writer, value, 0, maximumDepth);
                    writer.Flush();
                }
                return Encoding.UTF8.GetString(stream.ToArray());
            }
        }

        private static string CheckedString(string value)
        {
            // Never silently replace an invalid UTF-16 code unit while encoding.
            for (int i = 0; i < value.Length; ++i)
            {
                if (char.IsHighSurrogate(value[i]))
                {
                    if (++i >= value.Length || !char.IsLowSurrogate(value[i]))
                        throw new ArgumentException("EXACT_JSON_INVALID_SURROGATE");
                }
                else if (char.IsLowSurrogate(value[i]))
                    throw new ArgumentException("EXACT_JSON_INVALID_SURROGATE");
            }
            return value;
        }

        private static void Floating(Utf8JsonWriter writer, double value)
        {
            if (double.IsNaN(value) || double.IsInfinity(value))
                throw new ArgumentException("EXACT_JSON_NONFINITE");
            // The pinned host's R formatter emits a decimal that Python reads
            // one ULP away for 2^-25. G17 preserves portable binary64 identity.
            string text = value.ToString("G17", CultureInfo.InvariantCulture);
            // Preserve JSON float versus integer kind, including negative zero.
            if (!text.Contains(".") && !text.Contains("E") && !text.Contains("e"))
                text += ".0";
            writer.WriteRawValue(text, false);
        }

        private static void Write(Utf8JsonWriter writer, object value, int depth, int maximumDepth)
        {
            if (depth > maximumDepth)
                throw new ArgumentException("EXACT_JSON_DEPTH");
            if (value == null) { writer.WriteNullValue(); return; }
            if (value is PSObject wrapped)
            {
                if (wrapped.BaseObject is PSCustomObject)
                {
                    writer.WriteStartObject();
                    foreach (PSPropertyInfo property in wrapped.Properties)
                    {
                        if (property.MemberType != PSMemberTypes.NoteProperty)
                            throw new ArgumentException("EXACT_JSON_NONDATA_PROPERTY");
                        writer.WritePropertyName(CheckedString(property.Name));
                        Write(writer, property.Value, depth + 1, maximumDepth);
                    }
                    writer.WriteEndObject();
                    return;
                }
                Write(writer, wrapped.BaseObject, depth, maximumDepth);
                return;
            }
            if (value is string text) { StringValue(writer, text); return; }
            if (value is bool boolean) { writer.WriteBooleanValue(boolean); return; }
            if (value is double binary64) { Floating(writer, binary64); return; }
            if (value is float binary32) { Floating(writer, (double)binary32); return; }
            if (value is sbyte || value is byte || value is short || value is ushort
                || value is int || value is uint || value is long || value is ulong
                || value is BigInteger)
            {
                writer.WriteRawValue(((IFormattable)value).ToString(null, CultureInfo.InvariantCulture), false);
                return;
            }
            if (value is IDictionary dictionary)
            {
                writer.WriteStartObject();
                foreach (DictionaryEntry entry in dictionary)
                {
                    if (!(entry.Key is string key))
                        throw new ArgumentException("EXACT_JSON_NONSTRING_KEY");
                    writer.WritePropertyName(CheckedString(key));
                    Write(writer, entry.Value, depth + 1, maximumDepth);
                }
                writer.WriteEndObject();
                return;
            }
            if (value is IList list)
            {
                writer.WriteStartArray();
                foreach (object item in list) Write(writer, item, depth + 1, maximumDepth);
                writer.WriteEndArray();
                return;
            }
            // No implicit DateTime/decimal/arbitrary-object conversions in a
            // scientific transport. Its supported data types are explicit.
            throw new ArgumentException("EXACT_JSON_UNSUPPORTED_TYPE:" + value.GetType().FullName);
        }
    }
}
