package com.nightball;

/** Command-line shortcuts for testing several desktop windows on one computer. */
public final class LaunchOptions {
    public String name;
    public boolean host;
    /** Address to join, "ip" or "ip:port". */
    public String join;
    /** Host only: start the match as soon as a second player has joined. */
    public boolean autoStart;

    public static LaunchOptions parse(String[] args) {
        LaunchOptions options = new LaunchOptions();
        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            if ("--host".equals(arg)) {
                options.host = true;
            } else if ("--start".equals(arg)) {
                options.autoStart = true;
            } else if ("--join".equals(arg) && i + 1 < args.length) {
                options.join = args[++i];
            } else if ("--name".equals(arg) && i + 1 < args.length) {
                options.name = args[++i];
            }
        }
        return options;
    }
}
