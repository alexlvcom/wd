using System.Diagnostics;
using System.Text;

namespace Wd;

internal static class Program
{
    private const string Version = "1.0.0";
    private const string ShellTargetFileVariable = "WD_SHELL_TARGET_FILE";

    private static readonly HashSet<string> Commands = new(StringComparer.OrdinalIgnoreCase)
    {
        "add", "add!", "addcd", "rm", "remove", "list", "show", "path",
        "ls", "open", "clean", "help"
    };

    public static int Main(string[] args)
    {
        try
        {
            var options = Options.Parse(args);
            if (options.ShowVersion)
            {
                Console.WriteLine($"wd {Version}");
                return 0;
            }

            var store = new WarpStore(options.ConfigPath);
            if (options.Arguments.Count == 0)
            {
                PrintHelp();
                return 0;
            }

            var command = options.Arguments[0];
            var commandArgs = options.Arguments.Skip(1).ToArray();

            return command.ToLowerInvariant() switch
            {
                "add" => Add(store, commandArgs, options.Force, options.Quiet),
                "add!" => Add(store, commandArgs, true, options.Quiet),
                "addcd" => AddDirectory(store, commandArgs, options.Force, options.Quiet),
                "rm" or "remove" => Remove(store, commandArgs, options.Quiet),
                "list" => List(store, commandArgs),
                "show" => Show(store, commandArgs),
                "path" => PathCommand(store, commandArgs),
                "ls" => ListDirectory(store, commandArgs),
                "open" => Open(store, commandArgs, options.Quiet),
                "clean" => Clean(store, commandArgs, options.Force, options.Quiet),
                "help" => Help(commandArgs),
                _ => Warp(store, options.Arguments)
            };
        }
        catch (UsageException exception)
        {
            Error(exception.Message);
            return 2;
        }
        catch (IOException exception)
        {
            Error(exception.Message);
            return 1;
        }
        catch (UnauthorizedAccessException exception)
        {
            Error(exception.Message);
            return 1;
        }
        catch (Exception exception)
        {
            Error(exception.Message);
            return 1;
        }
    }

    private static int Add(WarpStore store, string[] args, bool force, bool quiet)
    {
        RequireAtMost(args, 1, "Usage: wd add [point] [--force]");
        var current = Directory.GetCurrentDirectory();
        var point = args.Length == 1 ? args[0] : DefaultPointName(current);
        return AddPoint(store, point, current, force, quiet);
    }

    private static int AddDirectory(WarpStore store, string[] args, bool force, bool quiet)
    {
        if (args.Length is < 1 or > 2)
            throw new UsageException("Usage: wd addcd <path> [point] [--force]");

        var target = System.IO.Path.GetFullPath(Environment.ExpandEnvironmentVariables(args[0]));
        if (!Directory.Exists(target))
            return Fail($"Directory does not exist: {target}");

        var point = args.Length == 2 ? args[1] : DefaultPointName(target);
        return AddPoint(store, point, target, force, quiet);
    }

    private static int AddPoint(WarpStore store, string point, string target, bool force, bool quiet)
    {
        ValidatePoint(point);
        var existing = store.Find(point);
        if (existing is not null && !force)
        {
            if (PathsEqual(existing.Target, target))
            {
                if (!quiet)
                    Console.WriteLine($"'{point}' already points to {target}");
                return 0;
            }

            return Fail($"Warp point '{point}' already exists. Use --force or 'wd add!' to overwrite it.");
        }

        store.Set(point, target);
        if (!quiet)
            Console.WriteLine(existing is null
                ? $"Added '{point}' -> {target}"
                : $"Updated '{point}' -> {target}");
        return 0;
    }

    private static int Remove(WarpStore store, string[] args, bool quiet)
    {
        RequireAtMost(args, 1, "Usage: wd rm [point]");
        var point = args.Length == 1 ? args[0] : DefaultPointName(Directory.GetCurrentDirectory());
        if (!store.Remove(point))
            return Fail($"Unknown warp point '{point}'");

        if (!quiet)
            Console.WriteLine($"Removed '{point}'");
        return 0;
    }

    private static int List(WarpStore store, string[] args)
    {
        RequireNone(args, "Usage: wd list");
        var points = store.Points.OrderBy(point => point.Name, StringComparer.OrdinalIgnoreCase).ToArray();
        if (points.Length == 0)
        {
            Console.WriteLine("No warp points saved.");
            return 0;
        }

        var width = points.Max(point => point.Name.Length);
        foreach (var point in points)
            Console.WriteLine($"{point.Name.PadRight(width)}  ->  {point.Target}");
        return 0;
    }

    private static int Show(WarpStore store, string[] args)
    {
        RequireAtMost(args, 1, "Usage: wd show [point]");
        if (args.Length == 1)
        {
            var point = store.Find(args[0]);
            return point is null
                ? Fail($"Unknown warp point '{args[0]}'")
                : Print($"{point.Name} -> {point.Target}");
        }

        var current = Directory.GetCurrentDirectory();
        var matches = store.Points.Where(point => PathsEqual(point.Target, current)).ToArray();
        if (matches.Length == 0)
            return Fail("No warp points reference the current directory.");

        foreach (var point in matches)
            Console.WriteLine($"{point.Name} -> {point.Target}");
        return 0;
    }

    private static int PathCommand(WarpStore store, string[] args)
    {
        RequireExactly(args, 1, "Usage: wd path <point>");
        var point = store.Find(args[0]);
        return point is null ? Fail($"Unknown warp point '{args[0]}'") : Print(point.Target);
    }

    private static int ListDirectory(WarpStore store, string[] args)
    {
        RequireExactly(args, 1, "Usage: wd ls <point>");
        var point = store.Find(args[0]);
        if (point is null)
            return Fail($"Unknown warp point '{args[0]}'");
        if (!Directory.Exists(point.Target))
            return Fail($"Directory does not exist: {point.Target}");

        foreach (var entry in Directory.EnumerateFileSystemEntries(point.Target)
                     .OrderBy(entry => entry, StringComparer.OrdinalIgnoreCase))
        {
            var name = System.IO.Path.GetFileName(entry);
            Console.WriteLine(Directory.Exists(entry) ? name + System.IO.Path.DirectorySeparatorChar : name);
        }
        return 0;
    }

    private static int Open(WarpStore store, string[] args, bool quiet)
    {
        RequireExactly(args, 1, "Usage: wd open <point>");
        var point = store.Find(args[0]);
        if (point is null)
            return Fail($"Unknown warp point '{args[0]}'");
        if (!Directory.Exists(point.Target))
            return Fail($"Directory does not exist: {point.Target}");

        Process.Start(new ProcessStartInfo("explorer.exe", $"\"{point.Target}\"") { UseShellExecute = true });
        if (!quiet)
            Console.WriteLine($"Opened {point.Target}");
        return 0;
    }

    private static int Clean(WarpStore store, string[] args, bool force, bool quiet)
    {
        RequireNone(args, "Usage: wd clean [--force]");
        var dead = store.Points.Where(point => !Directory.Exists(point.Target)).ToArray();
        if (dead.Length == 0)
        {
            if (!quiet)
                Console.WriteLine("No invalid warp points found.");
            return 0;
        }

        if (!force)
        {
            Console.Write($"Remove {dead.Length} invalid warp point(s)? [y/N] ");
            var answer = Console.ReadLine();
            if (!string.Equals(answer, "y", StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(answer, "yes", StringComparison.OrdinalIgnoreCase))
            {
                if (!quiet)
                    Console.WriteLine("Nothing removed.");
                return 0;
            }
        }

        foreach (var point in dead)
            store.Remove(point.Name, save: false);
        store.Save();
        if (!quiet)
            Console.WriteLine($"Removed {dead.Length} invalid warp point(s).");
        return 0;
    }

    private static int Warp(WarpStore store, IReadOnlyList<string> args)
    {
        if (args.Count > 2)
            throw new UsageException("Usage: wd <point> [subdirectory]");

        string target;
        var pointName = args[0];
        if (pointName.All(character => character == '.'))
        {
            if (pointName.Length < 2)
                return Fail("Warping to the current directory would have no effect.");

            target = Directory.GetCurrentDirectory();
            for (var level = 1; level < pointName.Length; level++)
            {
                var parent = Directory.GetParent(target);
                if (parent is null)
                    break;
                target = parent.FullName;
            }
        }
        else
        {
            var point = store.Find(pointName);
            if (point is null)
                return Fail($"Unknown warp point '{pointName}'");
            target = point.Target;
        }

        if (args.Count == 2)
            target = System.IO.Path.GetFullPath(System.IO.Path.Combine(target, args[1]));
        if (!Directory.Exists(target))
            return Fail($"Directory does not exist: {target}");

        var targetFile = Environment.GetEnvironmentVariable(ShellTargetFileVariable);
        if (string.IsNullOrWhiteSpace(targetFile))
            Console.WriteLine(target);
        else
            File.WriteAllText(targetFile, target, new UTF8Encoding(false));
        return 0;
    }

    private static int Help(string[] args)
    {
        RequireNone(args, "Usage: wd help");
        PrintHelp();
        return 0;
    }

    private static void PrintHelp()
    {
        Console.WriteLine("""
            wd - jump to bookmarked directories

            Usage:
              wd <point> [subdirectory]      Jump to a saved directory
              wd add [point]                 Save the current directory
              wd add! [point]                Save or overwrite the current directory
              wd addcd <path> [point]        Save another directory
              wd rm [point]                  Remove a point
              wd list                        List all points
              wd show [point]                Show a point, or points for the current directory
              wd path <point>                Print only the saved path
              wd ls <point>                  List a point's directory
              wd open <point>                Open a point in File Explorer
              wd clean                       Remove points whose directories no longer exist
              wd help                        Show this help

            Options:
              -f, --force                    Overwrite or clean without prompting
              -q, --quiet                    Suppress success messages
              -c, --config <file>            Use another warp-point file
              -v, --version                  Print version

            The default config is %USERPROFILE%\.warprc (or WD_CONFIG).
            """);
    }

    private static void ValidatePoint(string point)
    {
        if (string.IsNullOrWhiteSpace(point))
            throw new UsageException("Warp point cannot be empty.");
        if (point.All(character => character == '.'))
            throw new UsageException("Warp point cannot consist only of dots.");
        if (point.Any(char.IsWhiteSpace))
            throw new UsageException("Warp point cannot contain whitespace.");
        if (point.IndexOfAny([':', '/', '\\']) >= 0)
            throw new UsageException("Warp point contains an illegal character (: / \\). ");
        if (Commands.Contains(point))
            throw new UsageException($"'{point}' is a reserved command name.");
    }

    private static string DefaultPointName(string path)
    {
        var name = new DirectoryInfo(path).Name;
        if (string.IsNullOrWhiteSpace(name) || name.Contains(':'))
            throw new UsageException("The current directory has no usable default name; specify a point name.");
        return name;
    }

    private static bool PathsEqual(string left, string right) =>
        string.Equals(
            System.IO.Path.TrimEndingDirectorySeparator(System.IO.Path.GetFullPath(left)),
            System.IO.Path.TrimEndingDirectorySeparator(System.IO.Path.GetFullPath(right)),
            StringComparison.OrdinalIgnoreCase);

    private static int Print(string value)
    {
        Console.WriteLine(value);
        return 0;
    }

    private static int Fail(string message)
    {
        Error(message);
        return 1;
    }

    private static void Error(string message) => Console.Error.WriteLine($"wd: {message}");

    private static void RequireNone(string[] args, string usage)
    {
        if (args.Length != 0)
            throw new UsageException(usage);
    }

    private static void RequireExactly(string[] args, int count, string usage)
    {
        if (args.Length != count)
            throw new UsageException(usage);
    }

    private static void RequireAtMost(string[] args, int count, string usage)
    {
        if (args.Length > count)
            throw new UsageException(usage);
    }
}

internal sealed record WarpPoint(string Name, string Target);

internal sealed class WarpStore
{
    private readonly string _configPath;
    private readonly List<WarpPoint> _points = [];

    public WarpStore(string configPath)
    {
        _configPath = configPath;
        Load();
    }

    public IReadOnlyList<WarpPoint> Points => _points;

    public WarpPoint? Find(string name) =>
        _points.FirstOrDefault(point => string.Equals(point.Name, name, StringComparison.OrdinalIgnoreCase));

    public void Set(string name, string target)
    {
        var normalized = System.IO.Path.GetFullPath(target);
        var index = _points.FindIndex(point => string.Equals(point.Name, name, StringComparison.OrdinalIgnoreCase));
        if (index >= 0)
            _points[index] = new WarpPoint(name, normalized);
        else
            _points.Add(new WarpPoint(name, normalized));
        Save();
    }

    public bool Remove(string name, bool save = true)
    {
        var removed = _points.RemoveAll(point => string.Equals(point.Name, name, StringComparison.OrdinalIgnoreCase)) > 0;
        if (removed && save)
            Save();
        return removed;
    }

    public void Save()
    {
        var directory = System.IO.Path.GetDirectoryName(_configPath);
        if (!string.IsNullOrEmpty(directory))
            Directory.CreateDirectory(directory);

        var temporaryPath = _configPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            var contents = string.Join(Environment.NewLine, _points.Select(point => $"{point.Name}:{ContractHome(point.Target)}"));
            if (_points.Count > 0)
                contents += Environment.NewLine;
            File.WriteAllText(temporaryPath, contents, new UTF8Encoding(false));
            File.Move(temporaryPath, _configPath, true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
                File.Delete(temporaryPath);
        }
    }

    private void Load()
    {
        if (!File.Exists(_configPath))
            return;

        foreach (var line in File.ReadLines(_configPath))
        {
            if (string.IsNullOrWhiteSpace(line) || line.TrimStart().StartsWith('#'))
                continue;
            var separator = line.IndexOf(':');
            if (separator <= 0 || separator == line.Length - 1)
                continue;
            var name = line[..separator];
            var target = ExpandHome(line[(separator + 1)..]);
            _points.RemoveAll(point => string.Equals(point.Name, name, StringComparison.OrdinalIgnoreCase));
            _points.Add(new WarpPoint(name, target));
        }
    }

    private static string ContractHome(string path)
    {
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var normalizedHome = System.IO.Path.TrimEndingDirectorySeparator(home);
        if (string.Equals(path, normalizedHome, StringComparison.OrdinalIgnoreCase))
            return "~";
        if (path.StartsWith(normalizedHome + System.IO.Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            return "~" + path[normalizedHome.Length..];
        return path;
    }

    private static string ExpandHome(string path)
    {
        if (path == "~")
            return Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (path.StartsWith("~\\", StringComparison.Ordinal) || path.StartsWith("~/", StringComparison.Ordinal))
            return System.IO.Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                path[2..].Replace('/', System.IO.Path.DirectorySeparatorChar));
        return path;
    }
}

internal sealed class Options
{
    public required string ConfigPath { get; init; }
    public required List<string> Arguments { get; init; }
    public bool Force { get; init; }
    public bool Quiet { get; init; }
    public bool ShowVersion { get; init; }

    public static Options Parse(string[] args)
    {
        var remaining = new List<string>();
        string? config = null;
        var force = false;
        var quiet = false;
        var version = false;

        for (var index = 0; index < args.Length; index++)
        {
            switch (args[index])
            {
                case "-c" or "--config":
                    if (++index >= args.Length)
                        throw new UsageException("--config requires a file path.");
                    config = args[index];
                    break;
                case "-f" or "--force":
                    force = true;
                    break;
                case "-q" or "--quiet":
                    quiet = true;
                    break;
                case "-v" or "--version":
                    version = true;
                    break;
                default:
                    remaining.Add(args[index]);
                    break;
            }
        }

        config ??= Environment.GetEnvironmentVariable("WD_CONFIG");
        config ??= System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".warprc");
        config = ExpandConfigPath(Environment.ExpandEnvironmentVariables(config));

        return new Options
        {
            ConfigPath = config,
            Arguments = remaining,
            Force = force,
            Quiet = quiet,
            ShowVersion = version
        };
    }

    private static string ExpandConfigPath(string path)
    {
        if (path == "~")
            return Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (path.StartsWith("~\\", StringComparison.Ordinal) || path.StartsWith("~/", StringComparison.Ordinal))
            path = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), path[2..]);
        return System.IO.Path.GetFullPath(path);
    }
}

internal sealed class UsageException(string message) : Exception(message);
