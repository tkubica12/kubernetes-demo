package com.microsoft.azuresample.acscicdtodo.model;

import java.util.Date;

import com.fasterxml.jackson.annotation.JsonProperty;

public class ToDo {
    private String itemId;
    private String comment;
    private String category;
    private Date created;
    private Date updated;
    
    public ToDo(){

    }

    public ToDo(String itemId, String comment, String category, Date created, Date updated){
        this.setId(itemId);
        this.setComment(comment);
        this.setCategory(category);
        this.setCreated(created);
        this.setUpdated(updated);
    }

    @JsonProperty("itemId")
    public String getId() {
        return itemId;
    }

    @JsonProperty("itemId")
    public void setId(String id) {
        this.itemId = id;
    }

    @JsonProperty("comment")
    public String getComment() {
        return comment;
    }

    @JsonProperty("comment")
    public void setComment(String comment) {
        this.comment = comment;
    }

    @JsonProperty("category")
    public String getCategory() {
        return category;
    }

    @JsonProperty("category")
    public void setCategory(String category) {
        this.category = category;
    }

    @JsonProperty("created")
    public Date getCreated() {
        return created;
    }

    @JsonProperty("created")
    public void setCreated(Date created) {
        this.created = created;
    }

    @JsonProperty("updated")
    public Date getUpdated() {
        return updated;
    }

    @JsonProperty("updated")
    public void setUpdated(Date updated) {
        this.updated = updated;
    }

}