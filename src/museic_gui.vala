public class MuseicGui : Gtk.ApplicationWindow {

    private MuseIC museic_app;
    private Gtk.Builder builder;
    private Gtk.ListStore fileList;
    // Aux variables needed to open files
    private Gtk.Window files_window;
    private Gtk.FileChooserWidget chooser;

    public MuseicGui(MuseIC app) {
        Object (application: app, title: "MuseIC");
        museic_app = app;
        // Define main window
        this.set_position (Gtk.WindowPosition.CENTER);
        try {
            this.icon = new Gdk.Pixbuf.from_file ("data/museic_logo_64.png");
        }catch (GLib.Error e) {
            stdout.printf("Logo not found. Error: %s\n", e.message);
        }
        // Load interface from file
        this.builder = new Gtk.Builder ();
        try {
            builder.add_from_file ("src/museic_window.glade");
        }catch (GLib.Error e) {
            stdout.printf("Glade file not found. Error: %s\n", e.message);
        }
        // Connect signals
        builder.connect_signals (this);
        // Add main box to window
        this.add (builder.get_object ("mainBox") as Gtk.Box);
        // Show window
        this.show_all ();
        this.show ();
        // Start time function to update info about stream duration and position each second
        GLib.Timeout.add_seconds (1, update_stream_status);
    }

    [CCode(instance_pos=-1)]
    public void action_ant_file (Gtk.Button button) {
        if (this.museic_app.has_files()) {
            this.museic_app.ant_file();
            var notification = new Notification ("MuseIC");
            // Doesn't work :(
            try {
                notification.set_icon ( new Gdk.Pixbuf.from_file ("data/museic_logo_64.png"));
            }catch (GLib.Error e) {
                stdout.printf("Notification logo not found. Error: %s\n", e.message);
            }
            notification.set_body ("Previous File\n"+this.museic_app.get_current_file());
            this.museic_app.send_notification (this.museic_app.application_id, notification);
            update_stream_status();
        }
    }

    [CCode(instance_pos=-1)]
    public void action_seg_file (Gtk.Button button) {
        if (museic_app.has_files()) {
            this.museic_app.seg_file();
            var notification = new Notification ("MuseIC");
            // Doesn't work :(
            try {
                notification.set_icon ( new Gdk.Pixbuf.from_file ("data/museic_logo_64.png"));
            }catch (GLib.Error e) {
                stdout.printf("Notification logo not found. Error: %s\n", e.message);
            }
            notification.set_body ("Next File\n"+this.museic_app.get_current_file());
            this.museic_app.send_notification (this.museic_app.application_id, notification);
            update_stream_status();
        }
    }

    [CCode(instance_pos=-1)]
    public void action_play_file (Gtk.Button button) {
        if (this.museic_app.get_current_file() != "") {
            if (museic_app.state() == "pause")  {
                this.museic_app.play_file();
                button.set_label("gtk-media-pause");
            }else {
                this.museic_app.pause_file();
                button.set_label("gtk-media-play");
            }
        }
    }

    [CCode(instance_pos=-1)]
    public void action_open_file (Gtk.Button button) {
        create_file_open_window(true);
    }

    [CCode(instance_pos=-1)]
    public void action_add_file (Gtk.Button button) {
        create_file_open_window(false);
    }

    private void create_file_open_window(bool is_open) {
        this.files_window = new Gtk.Window();
        this.files_window.window_position = Gtk.WindowPosition.CENTER;
        this.files_window.destroy.connect (Gtk.main_quit);
        // VBox:
        Gtk.Box vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        this.files_window.add (vbox);
        // HeaderBar:
        Gtk.HeaderBar hbar = new Gtk.HeaderBar ();
        hbar.set_title ("Open Files");
        hbar.set_subtitle ("Select Files and Folders to open");
        this.files_window.set_titlebar (hbar);
        // Add a chooser:
        this.chooser = new Gtk.FileChooserWidget (Gtk.FileChooserAction.OPEN);
        vbox.pack_start (this.chooser, true, true, 0);
        // Multiple files can be selected:
        this.chooser.select_multiple = true;
        // Buttons
        Gtk.Box hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
        hbox.set_halign(Gtk.Align.CENTER);
        hbox.set_border_width(5);
        Gtk.Button cancel = new Gtk.Button.with_label ("Cancel");
        Gtk.Button select = new Gtk.Button.with_label ("Select");
        hbox.add (select);
        hbox.add (cancel);
        vbox.add(hbox);
        // Setup buttons callbacks
        cancel.clicked.connect (() => {this.files_window.destroy ();});
        if (is_open) select.clicked.connect (open_files);
        else select.clicked.connect (add_files);
        this.files_window.show_all ();
    }

    private void open_files () {
        SList<string> uris = this.chooser.get_uris ();
        foreach (unowned string uri in uris) {
            stdout.printf (" %s\n", uri);
        }
        this.files_window.destroy ();
        this.files_window = null;
        this.chooser = null;
    }

    private void add_files () {
        SList<string> uris = this.chooser.get_uris ();
        foreach (unowned string uri in uris) {
            stdout.printf (" %s\n", uri);
        }
        this.files_window.destroy ();
        this.files_window = null;
        this.chooser = null;
    }

    [CCode(instance_pos=-1)]
    public bool action_change_time (Gtk.Scale slider, Gtk.ScrollType scroll, double new_value) {
        this.museic_app.set_position((float)new_value);
        slider.adjustment.value = new_value;
        return true;
    }

    private bool update_stream_status() {
        if (!this.museic_app.has_files()) return true;
        StreamTimeInfo pos_info = this.museic_app.get_position_str();
        StreamTimeInfo dur_info = this.museic_app.get_duration_str();
        // Update time label
        (this.builder.get_object ("timeLabel") as Gtk.Label).set_label (pos_info.minutes+"/"+dur_info.minutes);
        // Update progres bar
        double progres = (double)pos_info.nanoseconds/(double)dur_info.nanoseconds;
        (this.builder.get_object ("scalebar") as Gtk.Scale).set_value (progres);
        // Update status label with filename
        (builder.get_object ("statusLabel") as Gtk.Label).set_label (this.museic_app.get_current_file());
        // Check if stream, has ended
        if (this.museic_app.state() == "endstream") action_seg_file((builder.get_object ("segButton") as Gtk.Button));
        return true;
    }

}
