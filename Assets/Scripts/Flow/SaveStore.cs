using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace RetroSF
{
    /// <summary>
    /// Unlocked endings on disk (Godot save_store.gd). Version 1 file:
    /// <c>{"version":1,"endings":["new_home", ...]}</c>.
    /// An unreadable or unsupported file is never overwritten: later endings stay in memory only.
    /// Writes go to a temporary file first and then replace the save in one step.
    /// </summary>
    public sealed class SaveStore
    {
        public const int Version = 1;

        public event Action<string> SaveFailed;

        public string SavePath { get; }
        public List<string> Unlocked { get; } = new List<string>();
        bool writable = true;

        public SaveStore(string savePath)
        {
            SavePath = savePath;
        }

        /// <summary>True when the file was read (or does not exist yet).</summary>
        public bool LoadProgress()
        {
            Unlocked.Clear();
            if (!File.Exists(SavePath))
            {
                writable = true;
                return true;
            }
            object root;
            try
            {
                string text = File.ReadAllText(SavePath, Encoding.UTF8);
                // Like an empty ConfigFile: readable, but without a version.
                root = string.IsNullOrWhiteSpace(text) ? null : Json.Parse(text);
            }
            catch (Exception)
            {
                writable = false;
                SaveFailed?.Invoke("기록을 읽을 수 없습니다. 기존 파일은 보존됩니다.");
                return false;
            }
            writable = true;
            var data = root as Dictionary<string, object>;
            object version = null;
            if (data == null || !data.TryGetValue("version", out version) || !(version is double number) || number != Version)
            {
                writable = false;
                SaveFailed?.Invoke("지원하지 않는 기록 버전입니다. 기존 파일은 보존됩니다.");
                return false;
            }
            object ids = data.TryGetValue("endings", out var value) ? value : new List<object>();
            if (!(ids is List<object> list))
            {
                writable = false;
                return false;
            }
            foreach (var id in list)
                if (id is string text && !Unlocked.Contains(text)) Unlocked.Add(text);
            return true;
        }

        /// <summary>Records an ending. False when it could only be kept in memory.</summary>
        public bool Unlock(string id)
        {
            if (string.IsNullOrEmpty(id)) return false;
            if (!Unlocked.Contains(id)) Unlocked.Add(id);
            if (!writable)
            {
                SaveFailed?.Invoke("이번 엔딩은 메모리에만 기록되었습니다. 저장 파일을 확인해주세요.");
                return false;
            }
            string temporary = SavePath + ".tmp";
            try
            {
                File.WriteAllText(temporary, Serialize(), new UTF8Encoding(false));
                ReplaceWith(temporary);
                return true;
            }
            catch (Exception)
            {
                SaveFailed?.Invoke("엔딩 저장에 실패했습니다. 디스크와 저장 경로를 확인해주세요.");
                return false;
            }
        }

        void ReplaceWith(string temporary)
        {
            if (!File.Exists(SavePath))
            {
                File.Move(temporary, SavePath);
                return;
            }
            try
            {
                File.Replace(temporary, SavePath, null);
            }
            catch (PlatformNotSupportedException)
            {
                File.Delete(SavePath);
                File.Move(temporary, SavePath);
            }
        }

        string Serialize()
        {
            var builder = new StringBuilder();
            builder.Append("{\"version\":").Append(Version.ToString(CultureInfo.InvariantCulture)).Append(",\"endings\":[");
            for (int i = 0; i < Unlocked.Count; i++)
            {
                if (i > 0) builder.Append(',');
                Json.Quote(builder, Unlocked[i]);
            }
            builder.Append("]}");
            return builder.ToString();
        }

        /// <summary>Minimal JSON reader: objects, arrays, strings, numbers (double), booleans and null.</summary>
        static class Json
        {
            public static object Parse(string text)
            {
                int index = 0;
                var value = ReadValue(text, ref index);
                SkipSpace(text, ref index);
                if (index != text.Length) throw new FormatException("Unexpected trailing characters.");
                return value;
            }

            public static void Quote(StringBuilder builder, string value)
            {
                builder.Append('"');
                foreach (char c in value)
                {
                    switch (c)
                    {
                        case '"': builder.Append("\\\""); break;
                        case '\\': builder.Append("\\\\"); break;
                        case '\n': builder.Append("\\n"); break;
                        case '\r': builder.Append("\\r"); break;
                        case '\t': builder.Append("\\t"); break;
                        case '\b': builder.Append("\\b"); break;
                        case '\f': builder.Append("\\f"); break;
                        default:
                            if (c < ' ') builder.Append("\\u").Append(((int)c).ToString("x4", CultureInfo.InvariantCulture));
                            else builder.Append(c);
                            break;
                    }
                }
                builder.Append('"');
            }

            static void SkipSpace(string s, ref int i)
            {
                while (i < s.Length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) i++;
            }

            static char Peek(string s, int i) => i < s.Length ? s[i] : '\0';

            static object ReadValue(string s, ref int i)
            {
                SkipSpace(s, ref i);
                switch (Peek(s, i))
                {
                    case '{': return ReadObject(s, ref i);
                    case '[': return ReadArray(s, ref i);
                    case '"': return ReadString(s, ref i);
                    case 't': Expect(s, ref i, "true"); return true;
                    case 'f': Expect(s, ref i, "false"); return false;
                    case 'n': Expect(s, ref i, "null"); return null;
                    default: return ReadNumber(s, ref i);
                }
            }

            static Dictionary<string, object> ReadObject(string s, ref int i)
            {
                var result = new Dictionary<string, object>();
                i++;
                SkipSpace(s, ref i);
                if (Peek(s, i) == '}')
                {
                    i++;
                    return result;
                }
                while (true)
                {
                    SkipSpace(s, ref i);
                    if (Peek(s, i) != '"') throw new FormatException("Expected a key.");
                    string key = ReadString(s, ref i);
                    SkipSpace(s, ref i);
                    if (Peek(s, i) != ':') throw new FormatException("Expected ':'.");
                    i++;
                    result[key] = ReadValue(s, ref i);
                    SkipSpace(s, ref i);
                    char next = Peek(s, i++);
                    if (next == '}') return result;
                    if (next != ',') throw new FormatException("Expected ',' or '}'.");
                }
            }

            static List<object> ReadArray(string s, ref int i)
            {
                var result = new List<object>();
                i++;
                SkipSpace(s, ref i);
                if (Peek(s, i) == ']')
                {
                    i++;
                    return result;
                }
                while (true)
                {
                    result.Add(ReadValue(s, ref i));
                    SkipSpace(s, ref i);
                    char next = Peek(s, i++);
                    if (next == ']') return result;
                    if (next != ',') throw new FormatException("Expected ',' or ']'.");
                }
            }

            static string ReadString(string s, ref int i)
            {
                var builder = new StringBuilder();
                i++;
                while (true)
                {
                    if (i >= s.Length) throw new FormatException("Unterminated string.");
                    char c = s[i++];
                    if (c == '"') return builder.ToString();
                    if (c != '\\')
                    {
                        builder.Append(c);
                        continue;
                    }
                    if (i >= s.Length) throw new FormatException("Unterminated escape.");
                    char escape = s[i++];
                    switch (escape)
                    {
                        case '"': case '\\': case '/': builder.Append(escape); break;
                        case 'b': builder.Append('\b'); break;
                        case 'f': builder.Append('\f'); break;
                        case 'n': builder.Append('\n'); break;
                        case 'r': builder.Append('\r'); break;
                        case 't': builder.Append('\t'); break;
                        case 'u':
                            if (i + 4 > s.Length) throw new FormatException("Bad unicode escape.");
                            builder.Append((char)int.Parse(s.Substring(i, 4), NumberStyles.HexNumber, CultureInfo.InvariantCulture));
                            i += 4;
                            break;
                        default: throw new FormatException("Bad escape.");
                    }
                }
            }

            static double ReadNumber(string s, ref int i)
            {
                int start = i;
                while (i < s.Length && "+-0123456789.eE".IndexOf(s[i]) >= 0) i++;
                if (i == start) throw new FormatException("Unexpected character.");
                return double.Parse(s.Substring(start, i - start), NumberStyles.Float, CultureInfo.InvariantCulture);
            }

            static void Expect(string s, ref int i, string word)
            {
                if (string.CompareOrdinal(s, i, word, 0, word.Length) != 0) throw new FormatException("Unexpected token.");
                i += word.Length;
            }
        }
    }
}
