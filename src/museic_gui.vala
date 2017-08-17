public class MuseicGui : Gtk.ApplicationWindow {

    private MuseIC museic_app;
    private Gtk.Builder builder;
    private Gtk.ListStore fileListStore;
    private Gtk.ListStore playListStore;
    // Aux variables needed to open files
    private Gtk.Window files_window;
    private Gtk.FileChooserWidget chooser;
    private bool is_open = false;

    public MuseicGui(MuseIC app) {
        Object (application: app, title: "MuseIC");
        museic_app = app;
        // Define main window
        this.set_position (Gtk.WindowPosition.CENTER);
        try {
            this.icon = new Gdk.Pixbuf.from_file (Constants.PKGDATADIR+"/data/museic-icon.svg");
        }catch (GLib.Error e) {
            stdout.printf("Logo not found. Error: %s\n", e.message);
        }
        // Load interface from file
        this.builder = new Gtk.Builder ();
        try {
            builder.add_from_file (Constants.PKGDATADIR+"/data/museic_window.glade");
        }catch (GLib.Error e) {
            stdout.printf("Glade file not found. Error: %s\n", e.message);
        }
        // Connect signals
        builder.connect_signals (this);
        // Add main box to window
        this.add (builder.get_object ("mainW") as Gtk.Grid);
        // Set fileListStore
        this.fileListStore = new Gtk.ListStore (5, typeof (string), typeof (string), typeof (string), typeof (string), typeof (Gdk.RGBA));
        var tree = (this.builder.get_object ("fileTree") as Gtk.TreeView);
        tree.set_model (this.fileListStore);
        tree.insert_column_with_attributes (-1, "Song", new Gtk.CellRendererText (), "text", 0, "background-rgba", 4);
        tree.get_column(0).set_resizable(true);
        tree.get_column(0).set_clickable(true);
        tree.get_column(0).set_min_width(200);
        tree.get_column(0).clicked.connect (sort_by_song);
        tree.insert_column_with_attributes (-1, "Artist", new Gtk.CellRendererText (), "text", 1, "background-rgba", 4);
        tree.get_column(1).set_resizable(true);
        tree.get_column(1).set_clickable(true);
        tree.get_column(1).set_min_width(200);
        tree.get_column(1).clicked.connect (sort_by_artist);
        tree.insert_column_with_attributes (-1, "Album", new Gtk.CellRendererText (), "text", 2, "background-rgba", 4);
        tree.get_column(2).set_resizable(true);
        tree.get_column(2).set_clickable(true);
        tree.get_column(2).set_min_width(200);
        tree.get_column(2).clicked.connect (sort_by_album);
        tree.insert_column_with_attributes (-1, "Status", new Gtk.CellRendererText (), "text", 3, "background-rgba", 4);
        // Set playListStore
        this.playListStore = new Gtk.ListStore (5, typeof (string), typeof (string), typeof (string), typeof (string), typeof (Gdk.RGBA));
        tree = (this.builder.get_object ("playTree") as Gtk.TreeView);
        tree.set_model (this.playListStore);
        tree.insert_column_with_attributes (-1, "Song", new Gtk.CellRendererText (), "text", 0, "background-rgba", 4);
        tree.get_column(0).set_resizable(true);
        tree.get_column(0).set_min_width(200);
        tree.insert_column_with_attributes (-1, "Artist", new Gtk.CellRendererText (), "text", 1, "background-rgba", 4);
        tree.get_column(1).set_resizable(true);
        tree.get_column(1).set_min_width(200);
        tree.insert_column_with_attributes (-1, "Album", new Gtk.CellRendererText (), "text", 2, "background-rgba", 4);
        tree.get_column(2).set_resizable(true);
        tree.get_column(2).set_min_width(200);
        tree.insert_column_with_attributes (-1, "Status", new Gtk.CellRendererText (), "text", 3, "background-rgba", 4);
        tree.get_column(3).set_resizable(true);
        // Show window
        this.show_all ();
        this.show ();
        // Start time function to update info about stream duration and position each second
        GLib.Timeout.add_seconds (1, update_stream_status);
        // Update tree view with files from library
        if (this.museic_app.get_filelist_len() > 0) {
            this.museic_app.play_filelist_file(0);
            update_files_to_tree();
            update_stream_status();
            update_playlist_to_tree();
        }
    }

    [CCode(instance_pos=-1)]
    public void action_ant_file (Gtk.Button button) {
        if (this.museic_app.has_files()) {
            this.museic_app.play_ant_file();
            var notification = new Notification ("MuseIC");
            try {
                notification.set_icon ( new Gdk.Pixbuf.from_file (Constants.PKGDATADIR+"/data/museic-icon.svg"));
            }catch (GLib.Error e) {
                stdout.printf("Notification logo not found. Error: %s\n", e.message);
            }
            notification.set_body ("Playing:\n"+this.museic_app.get_current_file().name);
            this.museic_app.send_notification (this.museic_app.application_id, notification);
            update_stream_status();
            update_playlist_to_tree();
        }
    }

    [CCode(instance_pos=-1)]
    public void action_seg_file (Gtk.Button button) {
        if (this.museic_app.has_files()) {
            this.museic_app.play_next_file();
            var notification = new Notification ("MuseIC");
            try {
                notification.set_icon ( new Gdk.Pixbuf.from_file (Constants.PKGDATADIR+"/data/museic-icon.svg"));
            }catch (GLib.Error e) {
                stdout.printf("Notification logo not found. Error: %s\n", e.message);
            }
            notification.set_body ("Playing:\n"+this.museic_app.get_current_file().name);
            this.museic_app.send_notification (this.museic_app.application_id, notification);
            update_stream_status();
            update_playlist_to_tree();
        }
    }

    [CCode(instance_pos=-1)]
    public void action_play_file (Gtk.Button button) {
        if (this.museic_app.has_files()) {
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
        // If we were playing, pause
        action_play_file((builder.get_object ("playButton") as Gtk.Button));
        create_file_open_window(true);
    }

    [CCode(instance_pos=-1)]
    public void action_add_file (Gtk.Button button) {
        create_file_open_window(!this.museic_app.has_files());
    }

    private void create_file_open_window(bool is_open_files) {
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
        this.is_open = is_open_files;
        select.clicked.connect (open_files);
        this.files_window.show_all ();
    }

    private void open_files () {
        string[] sfiles = {};
        SList<File> files = this.chooser.get_files ();
        foreach (unowned File file in files) {
            if (file.query_file_type(FileQueryInfoFlags.NONE) == FileType.REGULAR) sfiles += file.get_path();
            else if (file.query_file_type(FileQueryInfoFlags.NONE) == FileType.DIRECTORY) {
                string[] folder_files = rec_open(file);
                foreach (unowned string aux_file in folder_files) sfiles += file.get_path()+"/"+aux_file;
            }
        }
        if (this.is_open) {
            this.museic_app.clear_playlist();
            this.museic_app.clear_filelist();
            this.museic_app.clear_library();
        }
        this.museic_app.add_files_to_filelist(sfiles);
        if (this.is_open) this.museic_app.play_filelist_file(0);
        update_files_to_tree();
        update_stream_status();
        if (this.is_open) {
            update_playlist_to_tree();
            var notification = new Notification ("MuseIC");
            try {
                notification.set_icon ( new Gdk.Pixbuf.from_file (Constants.PKGDATADIR+"/data/museic_logo.png"));
            }catch (GLib.Error e) {
                stdout.printf("Notification logo not found. Error: %s\n", e.message);
            }
            notification.set_body ("Playing:\n"+this.museic_app.get_current_file().name);
            this.museic_app.send_notification (this.museic_app.application_id, notification);
        }
        this.files_window.destroy ();
        this.files_window = null;
        this.chooser = null;
        this.is_open = false;
    }

    private string[] rec_open(File file) {
        FileEnumerator enumerator = file.enumerate_children ("standard::*", FileQueryInfoFlags.NONE, null);
        string[] sfiles = {};
        FileInfo info = null;
        while ((info = enumerator.next_file (null)) != null) {
            if (info.get_file_type () == FileType.DIRECTORY) {
                string[] folder_files = rec_open(file.resolve_relative_path (info.get_name ()));
                foreach (unowned string aux_file in folder_files) sfiles += info.get_name ()+"/"+aux_file;
            }else sfiles += info.get_name();
        }
        return sfiles;
    }

    [CCode(instance_pos=-1)]
    public bool action_change_time (Gtk.Scale slider, Gtk.ScrollType scroll, double new_value) {
        this.museic_app.set_position((float)new_value);
        slider.adjustment.value = new_value;
        return true;
    }

    public void update_files_to_tree() {
        this.fileListStore.clear ();
        Gtk.TreeIter iter;
        foreach (MuseicFile file in this.museic_app.get_all_filelist_files()) {
            this.fileListStore.append (out iter);
            this.fileListStore.set (iter, 0, file.name, 1, file.artist, 2, file.album, -1);
        }
    }

    public void update_playlist_to_tree() {
        this.playListStore.clear ();
        Gtk.TreeIter iter;
        Gtk.TreeIter iterfile;
        MuseicFile[] aux = this.museic_app.get_all_playlist_files();
        MuseicFile file;
        Gdk.RGBA rgba_act = Gdk.RGBA ();
        rgba_act.parse ("#d0e5e3");
        Gdk.RGBA rgba_next = Gdk.RGBA ();
        rgba_next.parse ("#e7f2f1");
        int pos = museic_app.get_playlist_pos();
        for (int i=aux.length-1;i>=0;i--) {
            file = aux[i];
            this.playListStore.append (out iter);
            this.playListStore.set (iter, 0, file.name, 1, file.artist, 2, file.album, 3, "");
            if (i == pos) {
                this.playListStore.set (iter, 3, "Playing...", 4, rgba_act);
                if (this.playListStore.iter_previous(ref iter)) {
                    this.playListStore.set (iter, 3, "Next", 4, rgba_next);
                    this.fileListStore.get_iter_from_string(out iterfile, this.museic_app.get_next_filelist_pos().to_string());
                    this.fileListStore.set (iterfile, 3, "", 4, "");
                }else if (!this.museic_app.is_random()) {
                    int filepos = this.museic_app.get_next_filelist_pos();
                    this.fileListStore.get_iter_from_string(out iterfile, filepos.to_string());
                    this.fileListStore.set (iterfile, 3, "Next", 4, rgba_next);
                    if (this.museic_app.get_filelist_len() != 1) {
                        if (filepos == 0) filepos = this.museic_app.get_filelist_len()-1;
                        else filepos = filepos -1;
                        this.fileListStore.get_iter_from_string(out iterfile, filepos.to_string());
                        this.fileListStore.set (iterfile, 3, "", 4, "");
                    }
                }
                this.playListStore.iter_next(ref iter);
            }
        }

    }

    public bool update_stream_status() {
        if (!this.museic_app.has_files()) return true;
        StreamTimeInfo pos_info = this.museic_app.get_position_str();
        StreamTimeInfo dur_info = this.museic_app.get_duration_str();
        // Update time label
        (this.builder.get_object ("timeLabel") as Gtk.Label).set_label (pos_info.minutes+"/"+dur_info.minutes);
        // Update progres bar
        double progres = (double)pos_info.nanoseconds/(double)dur_info.nanoseconds;
        (this.builder.get_object ("scalebar") as Gtk.Scale).set_value (progres);
        // Update status label with filename
        (builder.get_object ("statusLabel") as Gtk.Label).set_label (this.museic_app.get_current_file().name);
        // Check if stream, has ended
        if (this.museic_app.state() == "endstream") action_seg_file((builder.get_object ("segButton") as Gtk.Button));
        return true;
    }

    [CCode(instance_pos=-1)]
    public void action_random (Gtk.ToggleButton button) {
        clean_files_status();
        this.museic_app.set_random(button.active);
        if (button.active) {
            Gdk.RGBA rgba = Gdk.RGBA ();
            rgba.parse ("#CCCCCC");
            button.override_background_color (Gtk.StateFlags.NORMAL,rgba);
        }else button.override_background_color (Gtk.StateFlags.NORMAL, null);
        update_playlist_to_tree();
    }

    [CCode(instance_pos=-1)]
    public void action_add_to_play (Gtk.Button button) {
        List<Gtk.TreePath> selected = (this.builder.get_object ("fileTree") as Gtk.TreeView).get_selection().get_selected_rows(null);
        int[] files_to_add = new int[selected.length()];
        int i = 0;
        foreach (Gtk.TreePath p in selected) {
            files_to_add[i] = int.parse(p.to_string());
            i++;
        }
        this.museic_app.add_files_to_playlist(files_to_add);
        update_playlist_to_tree();
    }

    [CCode(instance_pos=-1)]
    public void action_play_selected_file_playlist (Gtk.TreeView view, Gtk.TreePath path, Gtk.TreeViewColumn column) {
        this.museic_app.play_playlist_file(this.museic_app.get_all_playlist_files().length-1-int.parse(path.to_string()));
        clean_files_status();
        update_playlist_to_tree();
    }

    [CCode(instance_pos=-1)]
    public void action_play_selected_file_filelist (Gtk.TreeView view, Gtk.TreePath path, Gtk.TreeViewColumn column) {
        clean_files_status();
        this.museic_app.clear_playlist();
        this.museic_app.play_filelist_file(int.parse(path.to_string()));
        update_playlist_to_tree();
    }

    private void clean_files_status() {
        Gtk.TreeIter iter;
        this.fileListStore.get_iter_from_string(out iter, this.museic_app.get_next_filelist_pos().to_string());
        this.fileListStore.set (iter, 3, "", 4, "INCORRECTCOLOR");  // I use an string i know it's incorrect because i don't know how to say the tree to use the default color
    }

    private void sort_by_song() {
        if (this.museic_app.get_filelist_len() > 1) sort_filelist("name");
    }
    private void sort_by_artist() {
        if (this.museic_app.get_filelist_len() > 1) sort_filelist("artist");
    }
    private void sort_by_album() {
        if (this.museic_app.get_filelist_len() > 1) sort_filelist("album");
    }

    private void sort_filelist(string field) {
        // Sort filelist
        this.museic_app.set_filelist_sort_field(field);
        this.museic_app.sort_filelist();
        // Update tree view
        update_files_to_tree();
        // Set status of next file if necessari
        if (this.museic_app.get_playlist_pos() == this.museic_app.get_playlist_len()-1 & !this.museic_app.is_random()) {
            Gtk.TreeIter iterfile;
            Gdk.RGBA rgba_next = Gdk.RGBA ();
            rgba_next.parse ("#e7f2f1");
            int filepos = this.museic_app.get_next_filelist_pos();
            this.fileListStore.get_iter_from_string(out iterfile, filepos.to_string());
            this.fileListStore.set (iterfile, 3, "Next", 4, rgba_next);
            if (this.museic_app.get_filelist_len() != 1) {
                if (filepos == 0) filepos = this.museic_app.get_filelist_len()-1;
                else filepos = filepos -1;
                this.fileListStore.get_iter_from_string(out iterfile, filepos.to_string());
                this.fileListStore.set (iterfile, 3, "", 4, "");
            }
        }
    }

}
